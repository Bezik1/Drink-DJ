"""
Validation of a relational model diagram against the UML class diagram and the requirements matrix.
"""
import argparse
import json
import re
import subprocess
import sys
import zipfile
from collections import Counter
from pathlib import Path
from xml.sax.saxutils import unescape

SCRIPTS = Path(__file__).resolve().parent
SKILLS = SCRIPTS.parents[1]
ROOT = SKILLS.parents[1]

sys.dont_write_bytecode = True
sys.path.insert(0, str(SKILLS / "docx-to-pdf" / "scripts"))
sys.path.insert(0, str(SKILLS / "modify-relational" / "scripts"))
sys.path.insert(1, str(SCRIPTS))
sys.path.insert(2, str(SKILLS / "relational-constraints" / "scripts"))
sys.path.insert(3, str(SKILLS / "validate-erd" / "scripts"))
sys.path.insert(4, str(SKILLS / "requirements-coverage" / "scripts"))

from classes.RelationalModel import RelationalModel
from classes.UmlSource import UmlSource
from const.general import ER_ENDS, MARKERS, NAMES, PATHS, PATTERNS, SIZES
from drawio_relational import DrawioRelational
from lower_validation import LowerValidation
from requirements_coverage_model import RequirementsCoverage, relational_elements
from relational_constraints_model import RelationalConstraintsModel, output_paths
from utils.naming import constraints_stem
from utils.skills import uml_module
from utils.sql import child_end, column_text, is_sql_type, parent_end

GEOMETRY = uml_module("utils.geometry")


class RelationalValidator:
    """
    Validation of a relational model diagram. It reads the finished diagram,
    not the model, so it also finds changes made by hand. The expected content
    is the model, which is checked against the UML.

    Args:
        uml (Path, optional): JSON model of the UML. Default: the official one.
        erd (Path, optional): JSON model of the ERD. Default: the official one.
        matrix (str, optional): Matrix used, when the official one is missing.
    """

    def __init__(self, uml=None, erd=None, matrix=None):
        self.source = UmlSource(ROOT, uml, erd, matrix)()
        self.errors = []
        self.warnings = []
        self.notes = []

    def __call__(self, diagram, model=None, pdf=None):
        """
        Checks the diagram and collects problems.

        Args:
            diagram (Path): Path of the .drawio file.
            model (Path, optional): JSON model, that the diagram was made from.
            pdf (Path, optional): Official PDF of the diagram.

        Returns:
            bool: True, if there are no errors.
        """
        self.diagram = DrawioRelational(diagram)()
        self.errors.extend(self.diagram.errors)
        self.expected = None

        self.check_notation()
        self.check_layout()

        if model is None:
            self.notes.append("No model: the diagram is not compared with the UML, and the constraints are not checked.")
        else:
            try:
                self.expected = RelationalModel(model, self.source)()
                self.warnings.extend(self.expected.warnings)
            except RuntimeError as error:
                self.errors.append(str(error))

        if self.expected is not None:
            self.check_content()
            self.check_constraints(model)
            self.check_requirements_coverage(model)

        if pdf is not None:
            self.check_pdf(pdf)

        self.check_lower()
        self.report()

        return not self.errors

    def check_requirements_coverage(self, model):
        """
        Rule: the relational model serves every functional and non-functional
        requirement, as the coverage file of the `requirements-coverage` skill
        says. Every element and constraint, that it names, is in the model (a
        derived attribute, that is not stored, counts), every column with a
        length in `lengths` is long enough, and a gap of the relational model in
        a Must requirement is an error (in another one a warning).

        Args:
            model (Path): Path of the JSON model.
        """
        data = Path(model).resolve().with_name(f"{constraints_stem(Path(model).stem)}.json")
        ids = []

        if data.is_file():
            constraints = json.loads(data.read_text(encoding="utf-8"))
            ids = [item.get("id") for item in constraints.get("constraints", [])]
            ids += [key for item in constraints.get("constraints", []) for key in item.get("uml", [])]
            ids += list(constraints.get("covered", {}))

        types = {
            f"{name}.{column['name']}": column["type"]
            for name, table in self.expected.tables.items() for column in table["columns"]
        }
        coverage = RequirementsCoverage(ROOT, self.source.read_pdf_pages)()
        errors, warnings, notes = coverage.check("relational", relational_elements(self.expected.tables, ids), types)
        self.errors.extend(errors)
        self.warnings.extend(warnings)
        self.notes.extend(notes)

    def check_lower(self):
        """
        Rule: the UML class diagram, that the relational model is made from,
        is valid too. The `validate-uml` skill checks its diagram, model, PDF
        and constraints, and it runs `validate-erd` for the ERD below it. Each
        of their errors is an error of the relational model.
        """
        uml = self.source.path
        arguments = [uml.with_suffix(".drawio"), "--model", uml]

        if self.source.erd:
            arguments += ["--erd", self.source.erd]
        if self.source.given_matrix:
            arguments += ["--matrix", self.source.given_matrix]

        errors, notes = LowerValidation("UML", SKILLS / "validate-uml" / "scripts" / "validate_uml.py")(arguments)
        self.errors.extend(errors)
        self.notes.extend(notes)

    def check_notation(self):
        """
        Rules of the relational model diagram:
        - Every table has a unique name in snake case and at least one column.
        - Every column has a marker (<PK>, <FK>, <PK,FK> or none), a unique name
          in snake case and a SQL type with NULL or NOT NULL.
        - Every table has a primary key, and its columns are NOT NULL.
        - Every line joins 2 tables and has crow's foot ends. The end at the
          referenced table is "one" or "zero or one". A line has no label,
          because the <FK> markers show the foreign keys.
        - A table with a <FK> column has a line to another table, and a line
          starts at a table with a <FK> column.
        """
        tables = self.diagram.tables
        names = Counter(item["name"] for item in tables.values())

        if not tables:
            self.errors.append("The diagram has no tables")

        for item in tables.values():
            name = item["name"]

            if not re.fullmatch(PATTERNS["table"], name):
                self.errors.append(f"'{name}': the name of a table must be like Order_Item")
            if names[name] > 1:
                self.errors.append(f"{name}: the table is drawn {names[name]} times")
            if not item["columns"]:
                self.errors.append(f"{name}: the table has no columns")

            self.check_columns(item)

        for line in self.diagram.lines:
            self.check_line(line)

        sources = {line["source"] for line in self.diagram.lines}
        joined = sources | {line["target"] for line in self.diagram.lines}

        for identifier, item in tables.items():
            foreign = any("FK" in column["marker"] for column in item["columns"])

            if foreign and identifier not in sources:
                self.errors.append(f"{item['name']}: it has a <FK> column, but no line to the referenced table")
            if len(tables) > 1 and identifier not in joined:
                self.warnings.append(f"{item['name']}: the table is not joined to any other table")

    def check_columns(self, item):
        seen = set()

        for column in item["columns"]:
            label = f"{item['name']}.{column['name']}"

            if column["marker"] not in MARKERS.values():
                self.errors.append(f"{label}: marker '{column['marker']}' must be <PK>, <FK>, <PK,FK> or empty")
            if not re.fullmatch(PATTERNS["snake"], column["name"]):
                self.errors.append(f"{label}: the name of a column must be in snake_case")
            if column["name"] in seen:
                self.errors.append(f"{label}: the column is drawn twice")
            if column["null"] is None and "PK" not in column["marker"]:
                self.errors.append(f"{label}: '{column['type']}' must end with NULL or NOT NULL")
            elif not is_sql_type(column["type"]):
                self.errors.append(f"{label}: '{column['type']}' is not a SQL type")
            if "PK" in column["marker"] and column["null"]:
                self.errors.append(f"{label}: a column of the primary key must be NOT NULL")

            seen.add(column["name"])

        if item["columns"] and not any("PK" in column["marker"] for column in item["columns"]):
            self.errors.append(f"{item['name']}: the table has no primary key")

    def check_line(self, line):
        tables = self.diagram.tables
        name = f"Line {line['id']}"

        if line["source"] not in tables or line["target"] not in tables:
            self.errors.append(f"{name}: a line must join 2 tables")
            return

        name = f"Line {tables[line['source']]['name']} - {tables[line['target']]['name']}"

        if line["start"] not in ER_ENDS.values() or line["end"] not in ER_ENDS.values():
            self.errors.append(f"{name}: both ends need a crow's foot arrow ({', '.join(ER_ENDS.values())})")
        elif line["end"] not in (ER_ENDS["one"], ER_ENDS["zero_one"]):
            self.errors.append(f"{name}: the end at the referenced table must be one or zero or one")
        if line["labels"]:
            self.errors.append(f"{name}: a line has no label ('{line['labels'][0]}'), the <FK> markers show it")
        if not any("FK" in column["marker"] for column in tables[line["source"]]["columns"]):
            self.errors.append(f"{name}: the line must start at the table with the foreign key")

    def check_layout(self):
        """
        Rules: no table overlaps another one, every line has only horizontal
        and vertical stretches, and no line goes through a table, that it does
        not join. A line joins a key with a key: it starts at the left or the
        right side of a <FK> row and ends at the side of a <PK> row. No two
        ends of lines on one side of a table are closer than `end_gap`, and no
        two lines run on each other. Crossing lines are warnings.
        """
        tables = list(self.diagram.tables.values())

        for number, first in enumerate(tables):
            for second in tables[number + 1:]:
                if GEOMETRY.boxes_overlap(first["box"], second["box"]):
                    self.errors.append(f"{first['name']} overlaps {second['name']}")

        lines = [line for line in self.diagram.lines if line["points"]]

        if len(lines) < len(self.diagram.lines):
            self.notes.append("Some lines have no fixed ports, so their route is not checked.")

        for line in lines:
            name = self.describe(line)

            for first, second in zip(line["points"], line["points"][1:]):
                if abs(first[0] - second[0]) > 1 and abs(first[1] - second[1]) > 1:
                    self.errors.append(f"{name}: the line has a slanted stretch, use right angles only")
                    break

            self.check_rows(line, name)

            for identifier, item in self.diagram.tables.items():
                left, top, right, bottom = item["box"]
                inner = (left + 2, top + 2, right - 2, bottom - 2)

                if identifier not in (line["source"], line["target"]) and GEOMETRY.polyline_hits_box(line["points"], inner):
                    self.errors.append(f"{name}: the line goes through {item['name']}")

        self.check_overlaps(lines)

        for number, first in enumerate(lines):
            for second in lines[number + 1:]:
                if any(
                    GEOMETRY.segments_cross(a, b, c, d)
                    for a, b in zip(first["points"], first["points"][1:])
                    for c, d in zip(second["points"], second["points"][1:])
                ):
                    self.warnings.append(f"{self.describe(first)} crosses {self.describe(second)}")

    def check_overlaps(self, lines):
        """
        Checks, that no mark or stretch of a line hides another one. The
        draw.io file rounds the boxes to whole pixels, so a gap may be 1 px
        smaller than `end_gap`.

        Args:
            lines (dict[]): Lines with their points.
        """
        ends = {}

        for line in lines:
            for point, key in ((line["points"][0], "source"), (line["points"][-1], "target")):
                table = self.diagram.tables.get(line[key])

                if table is not None:
                    side = "left" if abs(point[0] - table["box"][0]) < 1.5 else "right"
                    ends.setdefault((table["name"], side), []).append((point[1], line))

        for (name, side), items in ends.items():
            items.sort(key=lambda item: item[0])

            for (first, one), (second, two) in zip(items, items[1:]):
                if second - first < SIZES["end_gap"] - 1:
                    self.errors.append(
                        f"{self.describe(one)} and {self.describe(two)} end on each other "
                        f"on the {side} side of {name}"
                    )

        for number, first in enumerate(lines):
            for second in lines[number + 1:]:
                if self.shared_trunk(first, second):
                    continue
                if any(
                    GEOMETRY.collinear_overlap(a, b, c, d) > 1
                    for a, b in zip(first["points"], first["points"][1:])
                    for c, d in zip(second["points"], second["points"][1:])
                ):
                    self.errors.append(f"{self.describe(first)} runs on {self.describe(second)}")

    def shared_trunk(self, first, second):
        """
        Tells, whether two lines leave the same side of the same table, so
        their first stretch is one trunk, which is not an error.

        Args:
            first (dict[]): One line, with its points.
            second (dict[]): The other line.

        Returns:
            bool: True, when both start at the same side of the same table.
        """
        if first["source"] != second["source"] or first["source"] not in self.diagram.tables:
            return False

        box = self.diagram.tables[first["source"]]["box"]
        sides = [
            "left" if abs(line["points"][0][0] - box[0]) < 1.5 else "right"
            for line in (first, second)
        ]

        return sides[0] == sides[1]

    def check_rows(self, line, name):
        """
        Checks, that a line leaves a foreign key row and enters a primary key row.

        Args:
            line (dict[]): The line, with its points.
            name (str): Description of the line for a message.
        """
        for point, key, marker, role in (
            (line["points"][0], "source", "FK", "a foreign key"),
            (line["points"][-1], "target", "PK", "a primary key"),
        ):
            table = self.diagram.tables.get(line[key])

            if table is None:
                continue

            left, _, right, _ = table["box"]
            on_side = min(abs(point[0] - left), abs(point[0] - right)) < 1.5
            row = next((column for column in table["columns"]
                        if column["rows"][0] - 0.5 <= point[1] <= column["rows"][1] + 0.5), None)

            if not on_side or row is None or marker not in row["marker"]:
                self.errors.append(
                    f"{name}: the line must {'start' if key == 'source' else 'end'} at the side of "
                    f"the row of {role} in {table['name']}, not at a random place of the table"
                )

    def describe(self, line):
        tables = self.diagram.tables
        names = [tables[key]["name"] if key in tables else "?" for key in (line["source"], line["target"])]

        return f"Line {names[0]} - {names[1]}"

    def check_content(self):
        """
        Rules: the diagram has exactly the tables of the model, each with its
        columns in the same order, markers, types and NULL, and one line for
        every foreign key, with the crow's foot ends of the model.
        """
        model = self.expected
        drawn = {item["name"]: item for item in self.diagram.tables.values()}

        for name in sorted(set(model.tables) - set(drawn)):
            self.errors.append(f"{name}: the table of the model is not drawn")
        for name in sorted(set(drawn) - set(model.tables)):
            self.errors.append(f"{name}: the table is not in the model")

        for name, table in model.tables.items():
            if name not in drawn:
                continue

            expected = [
                (model.marker(name, column["name"]), column["name"],
                 column_text(column, "PK" in model.marker(name, column["name"])))
                for column in table["columns"]
            ]
            found = [
                (column["marker"], column["name"], column["type"] if column["null"] is None
                 else f"{column['type']} {'NULL' if column['null'] else 'NOT NULL'}")
                for column in drawn[name]["columns"]
            ]

            if expected != found:
                self.errors.append(f"{name}: the columns differ from the model. Draw it again from the model.")

        self.compare_lines()

    def compare_lines(self):
        """
        Rules: every column of every foreign key has exactly one line to the
        column of the primary key, that it references (two foreign keys, that
        join the same two columns, share it), with the crow's foot ends of
        the foreign key. No line joins two other rows.
        """
        model, tables = self.expected, self.diagram.tables
        expected, found = Counter(), Counter()

        for name, table in model.tables.items():
            for item in table.get("foreign_keys", []):
                nullable = any(model.column(name, column)["null"] for column in item["columns"])
                ends = (child_end(item["multiplicity"]), parent_end(nullable))

                pairs = [model.line_pair(name, item)]

                if SIZES["line_per_column"]:
                    pairs = list(zip(item["columns"], item["to"]))

                for column, referenced in pairs:
                    expected[(name, column, item["references"], referenced)] = ends

        for line in self.diagram.lines:
            if not line["points"] or line["source"] not in tables or line["target"] not in tables:
                continue

            source, target = tables[line["source"]], tables[line["target"]]
            key = (source["name"], self.row_name(source, line["points"][0]),
                   target["name"], self.row_name(target, line["points"][-1]))
            found[key] += 1

            if key not in expected:
                self.errors.append(
                    f"{self.describe(line)}: it joins {key[0]}.{key[1]} with {key[2]}.{key[3]}, which is not "
                    "a foreign key column and the primary key column, that it references"
                )
            elif (line["start"], line["end"]) != expected[key]:
                self.errors.append(
                    f"{self.describe(line)}: its ends must be {expected[key][0]} and {expected[key][1]}"
                )

        for key in expected:
            if found[key] != 1:
                self.errors.append(
                    f"{key[0]}.{key[1]} -> {key[2]}.{key[3]}: the key pair has {found[key]} lines instead of 1"
                )

    @staticmethod
    def row_name(table, point):
        return next(
            (column["name"] for column in table["columns"] if column["rows"][0] - 0.5 <= point[1] <= column["rows"][1] + 0.5),
            None,
        )

    def check_pdf(self, pdf):
        names = self.expected.names() if self.expected else [
            name for item in self.diagram.tables.values()
            for name in [item["name"]] + [column["name"] for column in item["columns"]]
        ]
        pages = self.source.read_pdf_pages(pdf)
        content = re.sub(r"\s+", "", "".join(line for page in pages for line in page)).casefold()
        missing = [name for name in names if re.sub(r"\s+", "", name).casefold() not in content]

        if len(pages) != 1:
            self.errors.append(f"{pdf.name}: it has {len(pages)} pages instead of 1")
        if missing:
            self.errors.append(f"{pdf.name}: missing {', '.join(missing)}")

    def check_constraints(self, model):
        """
        Rules: the constraints, that the diagram cannot show, are in the file
        `<name>_constraints.json`, valid for the model, the UML constraints and
        the matrix, with the Word file next to it and the PDF in the documents.

        Args:
            model (Path): Path of the JSON model.
        """
        data = Path(model).resolve().with_name(f"{constraints_stem(Path(model).stem)}.json")
        document, pdf = output_paths(data)
        command = f"relational_constraints.py draft, then build {data.name}"

        if not data.is_file():
            self.errors.append(f"{data.name} is missing. Create it with the relational-constraints skill ({command})")
            return

        try:
            constraints = RelationalConstraintsModel(data, self.source, self.expected)()
        except RuntimeError as error:
            self.errors.append(str(error))
            return

        for path in (document, pdf):
            if not path.is_file():
                self.errors.append(f"{path.name} is missing. Run: relational_constraints.py build {data.name}")

        if not document.is_file():
            return

        try:
            with zipfile.ZipFile(document) as archive:
                text = archive.read("word/document.xml").decode("utf-8")
        except (OSError, KeyError, zipfile.BadZipFile):
            self.errors.append(f"{document.name} is not a Word document")
            return

        content = re.sub(r"\s+", " ", unescape("".join(re.findall(r"<w:t[^>]*>(.*?)</w:t>", text, re.S))))

        for item in constraints.items:
            if re.sub(r"\s+", " ", item["text"]) not in content:
                self.errors.append(f"{document.name}: {item['id']} is missing or old. Build it again.")

    def report(self):
        print(f"Tables: {len(self.diagram.tables)}, lines: {len(self.diagram.lines)}")

        for label, items in (("Error", self.errors), ("Warning", self.warnings), ("Note", self.notes)):
            for item in items:
                print(f"{label}: {item}")

        print("INVALID" if self.errors else "VALID")


def parse_args():
    parser = argparse.ArgumentParser(description="Validate a relational model diagram.")
    parser.add_argument(
        "diagram", nargs="?", type=Path, default=ROOT / PATHS["artifacts"] / f"{NAMES['default']}.drawio",
    )
    parser.add_argument("--model", type=Path)
    parser.add_argument("--pdf", type=Path)
    parser.add_argument("--uml", type=Path)
    parser.add_argument("--erd", type=Path)
    parser.add_argument("--matrix")

    return parser.parse_args()


def find_related(diagram, model, pdf):
    """
    Finds the model and the PDF with the same name as the diagram.

    Args:
        diagram (Path): Path of the .drawio file.
        model (Path, optional): Given model.
        pdf (Path, optional): Given PDF.

    Returns:
        Path[2]: Model and PDF, that can be None.
    """
    model = model or next(iter(p for p in [diagram.with_suffix(".json")] if p.is_file()), None)
    pdf = pdf or next(iter(
        p for p in [ROOT / PATHS["documents"] / f"{diagram.stem}.pdf"] if p.is_file()
    ), None)

    return model, pdf


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="replace")
    args = parse_args()

    try:
        if not args.diagram.is_file():
            raise RuntimeError(f"Diagram not found: {args.diagram}")

        model, pdf = find_related(args.diagram.resolve(), args.model, args.pdf)
        validator = RelationalValidator(args.uml, args.erd, args.matrix)

        sys.exit(0 if validator(args.diagram, model, pdf) else 1)
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(error)
        sys.exit(2)
