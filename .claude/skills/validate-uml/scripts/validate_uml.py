"""
Validation of a UML class diagram against the ERD and the requirements matrix.
"""
import argparse
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path
from xml.sax.saxutils import unescape

SCRIPTS = Path(__file__).resolve().parent
SKILLS = SCRIPTS.parents[1]
ROOT = SKILLS.parents[1]

sys.dont_write_bytecode = True
sys.path.insert(0, str(SKILLS / "docx-to-pdf" / "scripts"))
sys.path.insert(0, str(SKILLS / "modify-uml" / "scripts"))
sys.path.insert(1, str(SCRIPTS))
sys.path.insert(2, str(SKILLS / "uml-constraints" / "scripts"))
sys.path.insert(3, str(SKILLS / "validate-erd" / "scripts"))
sys.path.insert(4, str(SKILLS / "requirements-coverage" / "scripts"))

from classes.ErdSource import ErdSource
from classes.UmlDraft import UmlDraft
from classes.UmlModel import UmlModel
from const.general import NAMES, PATHS, PRIMITIVES
from constraints_const import SUFFIX as CONSTRAINTS_SUFFIX
from constraints_model import ConstraintsModel
from drawio_uml import DrawioUml
from lower_validation import LowerValidation
from requirements_coverage_model import RequirementsCoverage, uml_elements
from utils.geometry import boxes_overlap, polyline_hits_box, segments_cross
from utils.naming import end_class, is_multiplicity


class UmlValidator:
    """
    Validation of a UML class diagram. It reads the finished diagram, not the
    model, so it also finds changes made by hand. The expected content is the
    model, when there is one, and else the transformation of the ERD.

    Args:
        erd (Path, optional): JSON model of the ERD. Default: the official one.
        matrix (str, optional): Matrix used, when the official one is missing.
    """

    def __init__(self, erd=None, matrix=None):
        self.source = ErdSource(ROOT, erd, matrix)()
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
        self.uml = DrawioUml(diagram)()
        self.errors.extend(self.uml.errors)
        self.typed = model is not None

        if model is not None:
            try:
                self.expected = UmlModel(model, self.source)()
                self.expected_data = self.expected.data
            except RuntimeError as error:
                self.errors.append(str(error))
                self.expected_data = None
        else:
            self.expected_data = UmlDraft(self.source)()
            self.notes.append(
                "No model: the types of attributes are not checked, "
                "and the notes, that the ERD does not need, are not checked."
            )

        self.check_notation()
        self.check_layout()
        self.check_lines()

        if self.expected_data is not None:
            self.check_content()
            self.check_requirements()

        if pdf is not None:
            self.check_pdf(pdf)

        if model is not None and self.expected_data is not None:
            self.check_constraints(diagram, model)
            self.check_requirements_coverage(model)

        self.check_lower()
        self.report()

        return not self.errors

    def check_requirements_coverage(self, model):
        """
        Rule: the UML serves every functional and non-functional requirement,
        as the coverage file of the `requirements-coverage` skill says. Every
        element and UML constraint, that it names, is in the UML, and a gap of
        the UML in a Must requirement is an error (in another one a warning).

        Args:
            model (Path): Path of the JSON model.
        """
        data = Path(model).resolve().with_name(f"{Path(model).stem}{CONSTRAINTS_SUFFIX}.json")
        constraints = json.loads(data.read_text(encoding="utf-8")).get("constraints", []) if data.is_file() else []
        elements = uml_elements(self.expected_data["classes"], self.expected_data["associations"], constraints)
        coverage = RequirementsCoverage(ROOT, self.source.read_pdf_pages)()
        errors, warnings, notes = coverage.check("uml", elements)
        self.errors.extend(errors)
        self.warnings.extend(warnings)
        self.notes.extend(notes)

    def check_lower(self):
        """
        Rule: the ERD, that the UML is made from, is valid too. The
        `validate-erd` skill checks its diagram, model and PDF, and each of its
        errors is an error of the UML.
        """
        erd = self.source.path
        arguments = [erd.with_suffix(".drawio"), "--model", erd]

        if self.source.given_matrix:
            arguments += ["--matrix", self.source.given_matrix]

        errors, notes = LowerValidation("ERD", SKILLS / "validate-erd" / "scripts" / "validate_erd.py")(arguments)
        self.errors.extend(errors)
        self.notes.extend(notes)

    def declared_types(self):
        return [
            *PRIMITIVES,
            *(item["name"] for item in self.uml.classes.values() if item["stereotype"]),
        ]

    def check_notation(self):
        """
        Rules of the UML class diagram:
        - Every class has a name, and a name is used once.
        - Every attribute is `+ name : Type`, and its type is primitive, an
          enumeration or a data type of the diagram.
        - An enumeration has values and no attributes.
        - An association joins 2 classes, has a name, no arrow, and a
          multiplicity at every end. A composition has 1 or 0..1 at its whole.
        - Every class is joined to another one, or is an enumeration, a data type
          or an association class.
        """
        uml, types, names = self.uml, self.declared_types(), set()

        if not uml.classes:
            self.errors.append("The diagram has no classes")

        for item in uml.classes.values():
            if not item["name"]:
                self.errors.append(f"Class {item['id']} has no name")
            if item["name"] in names:
                self.errors.append(f"{item['name']}: the class is drawn twice")
            if item["stereotype"] == "enumeration" and not item["values"]:
                self.errors.append(f"{item['name']}: enumeration has no values")

            names.add(item["name"])

            for attribute in item["attributes"]:
                if attribute["type"] not in types:
                    self.errors.append(
                        f"{item['name']}.{attribute['name']}: type '{attribute['type']}' is not "
                        "a primitive type, an enumeration or a data type of the diagram"
                    )

        linked = set()

        for line in uml.associations:
            first, second = uml.classes.get(line["source"]), uml.classes.get(line["target"])

            if line["dashed"]:
                linked.update(identifier for identifier in (line["source"], line["target"]))
                continue
            if first is None or second is None:
                self.errors.append(f"A line {line['id']} does not join two classes")
                continue

            title = f"{line['name'] or '?'} ({first['name']} - {second['name']})"
            linked.update((line["source"], line["target"]))

            if not line["name"]:
                self.errors.append(f"{title}: association has no name")
            if line["arrows"]:
                self.errors.append(f"{title}: association has an arrow")
            if first["stereotype"] or second["stereotype"]:
                self.errors.append(f"{title}: an enumeration or data type is not joined by a line")

            for key in ("source_multiplicity", "target_multiplicity"):
                if not is_multiplicity(line[key] or ""):
                    self.errors.append(f"{title}: multiplicity of an end is missing or wrong")

            if line["kind"] == "composition" and line["target_multiplicity"] not in ("1", "0..1"):
                self.errors.append(f"{title}: the whole of a composition has multiplicity 1 or 0..1")

        for identifier, item in uml.classes.items():
            if identifier not in linked and not item["stereotype"]:
                self.errors.append(f"{item['name']}: the class has no line")

    def check_layout(self):
        shapes = [*self.uml.classes.values(), *self.uml.notes.values()]

        if self.uml.notes:
            self.warnings.append(
                f"The diagram has {len(self.uml.notes)} notes. Constraints belong to the Word file of the uml-constraints skill, and the diagram has no notes."
            )

        for number, first in enumerate(shapes):
            for second in shapes[number + 1:]:
                if boxes_overlap(self.corners(first), self.corners(second)):
                    self.errors.append(
                        f"{self.title(first)} and {self.title(second)} overlap"
                    )

    def check_lines(self):
        """
        Rules of readable lines:
        - Every line has only horizontal and vertical stretches.
        - A line does not go through a class, that it does not join.
        - Crossing lines are only a warning.
        """
        routes = []

        for line in self.uml.associations:
            points = self.uml.route(line)
            title = line["name"] or "attachment"

            if len(points) < 2:
                continue

            routes.append((title, line, points))

            for first, second in zip(points, points[1:]):
                if abs(first[0] - second[0]) > 1 and abs(first[1] - second[1]) > 1:
                    self.errors.append(f"{title}: the line is diagonal, use right angles")
                    break

            for identifier, item in self.uml.classes.items():
                if identifier in (line["source"], line["target"]):
                    continue

                x, y, width, height = item["box"]

                if polyline_hits_box(points, (x + 2, y + 2, x + width - 2, y + height - 2)):
                    self.errors.append(f"{title}: the line goes through {item['name']}")

        for number, (first, _, one) in enumerate(routes):
            for second, _, two in routes[number + 1:]:
                if any(
                    segments_cross(a, b, c, d)
                    for a, b in zip(one, one[1:]) for c, d in zip(two, two[1:])
                ):
                    self.warnings.append(f"The lines '{first}' and '{second}' cross")

    @staticmethod
    def corners(item):
        x, y, width, height = item["box"]

        return x, y, x + width, y + height

    @staticmethod
    def title(item):
        return item.get("name") or f"Note '{item['text'][:25]}'"

    def check_content(self):
        """
        Compares the diagram with the expected classes, attributes,
        and associations. A missing thing is an error. An extra thing is
        an error with a model, and else a warning.
        """
        data = self.expected_data
        by_name = {item["name"]: item for item in self.uml.classes.values()}
        extra = self.errors if self.typed else self.warnings

        for expected in data["classes"].values():
            item = by_name.pop(expected["name"], None)

            if item is None:
                self.errors.append(f"{expected['name']}: the class is missing in the diagram")
                continue

            self.compare_class(expected, item, extra)

        for name in by_name:
            extra.append(f"{name}: the class is not in {'the model' if self.typed else 'the ERD'}")

        self.compare_associations(data, extra)

    def compare_class(self, expected, item, extra):
        if expected.get("stereotype") != item["stereotype"]:
            self.errors.append(f"{expected['name']}: stereotype must be {expected.get('stereotype')}")
        if expected.get("stereotype") == "enumeration":
            if set(expected["values"]) != set(item["values"]):
                self.errors.append(f"{expected['name']}: values must be {expected['values']}")
            return

        found = {attribute["name"]: attribute for attribute in item["attributes"]}

        for attribute in expected.get("attributes", []):
            actual = found.pop(attribute["name"], None)
            title = f"{expected['name']}.{attribute['name']}"

            if actual is None:
                self.errors.append(f"{title}: the attribute is missing in the diagram")
                continue
            if self.typed and actual["type"] != attribute["type"]:
                self.errors.append(f"{title}: type must be {attribute['type']}, not {actual['type']}")

            kind = attribute.get("kind", "simple")

            if (kind == "key") != actual["key"] and not actual["partial"]:
                self.errors.append(f"{title}: a key must be underlined, and only a key")
            if (kind == "partial") != actual["partial"]:
                self.errors.append(f"{title}: a partial key must have a dashed underline, and only it")
            if (kind == "derived") != actual["derived"]:
                self.errors.append(f"{title}: a derived attribute has a slash, and only it")
            if kind == "multivalued" and not actual["multiplicity"]:
                self.errors.append(f"{title}: multivalued attribute needs a multiplicity")

        for name in found:
            extra.append(f"{expected['name']}.{name}: the attribute is not in {'the model' if self.typed else 'the ERD'}")

        self.compare_operations(expected, item, extra)

    def compare_operations(self, expected, item, extra):
        """
        Rules: every operation of the model is drawn with the same parameters
        and return type, and the diagram has no other operation.

        Args:
            expected (dict[]): The class of the model, or of the draft.
            item (dict[]): The class of the diagram.
            extra (str[]): List for a thing, that is not expected.
        """
        found = {operation["name"]: operation for operation in item["operations"]}

        for operation in expected.get("operations", []):
            actual = found.pop(operation["name"], None)
            title = f"{expected['name']}.{operation['name']}()"

            if actual is None:
                self.errors.append(f"{title}: the operation is missing in the diagram")
            elif self.typed and (
                actual["parameters"] != [{"name": p["name"], "type": p["type"]} for p in operation.get("parameters", [])]
                or actual["returns"] != operation.get("returns")
            ):
                self.errors.append(f"{title}: its parameters and return type must be as in the model")

        for name in found:
            extra.append(f"{expected['name']}.{name}(): the operation is not in {'the model' if self.typed else 'the ERD'}")

    def compare_associations(self, data, extra):
        """
        Compares the drawn associations with the model.

        Rules:
        - Every association is one line with its name and the multiplicity
          of each end. The ends are pairs of a class and a multiplicity, so an
          association of a class with itself (a loop) is compared, too.
        - A composition has its diamond at the whole.

        Args:
            data (dict[]): The model, or the draft from the ERD.
            extra (str[]): List for a thing, that is not expected.
        """
        names = {identifier: item["name"] for identifier, item in self.uml.classes.items()}
        found = {}

        for line in self.uml.associations:
            if line["dashed"] or line["source"] not in names or line["target"] not in names:
                continue

            ends = sorted([
                (names[line["source"]], line["source_multiplicity"]),
                (names[line["target"]], line["target_multiplicity"]),
            ])
            found.setdefault((line["name"], tuple(sorted({name for name, _ in ends}))), []).append((line, ends))

        for item in data["associations"]:
            ends = sorted(
                (data["classes"][end_class(key)]["name"], value) for key, value in item["ends"].items()
            )
            classes = tuple(sorted({name for name, _ in ends}))
            matches = found.pop((item["name"], classes), [])

            if len(matches) != 1:
                self.errors.append(
                    f"{item['name']} ({' - '.join(classes)}): the association is {len(matches)} lines instead of 1"
                )
                continue

            line, actual = matches[0]

            if actual != ends:
                self.errors.append(f"{item['name']}: multiplicities must be {ends}, not {actual}")
            if (item.get("kind", "association") == "composition") != (line["kind"] == "composition"):
                self.errors.append(f"{item['name']}: composition and association are mixed up")
            elif line["kind"] == "composition":
                whole = data["classes"][item["whole"]]["name"]
                target = names[line["target"]]

                if target != whole:
                    self.errors.append(f"{item['name']}: the diamond must be at {whole}")

        for name, classes in found:
            extra.append(f"{name} ({' - '.join(classes)}): the association is not in {'the model' if self.typed else 'the ERD'}")

    def check_requirements(self):
        """
        Reports what the matrix asks for and the UML does not draw.
        """
        erd = self.source.model

        for requirement, reason in erd.not_drawn.items():
            self.warnings.append(f"{requirement} is not drawn in the ERD, so not in the UML: {reason}")

        if self.typed:
            for item in self.assumed():
                self.warnings.append(f"Assumed: {item}")

    def assumed(self):
        data, found = self.expected_data, []

        for item in data["classes"].values():
            if item.get("assumed"):
                found.append(f"{item['name']}: {item['assumed']}")

            for attribute in item.get("attributes", []):
                if attribute.get("assumed"):
                    found.append(f"{item['name']}.{attribute['name']}: {attribute['assumed']}")

        for item in data["associations"]:
            if item.get("assumed"):
                found.append(f"{item['name']}: {item['assumed']}")

        return found

    def check_constraints(self, diagram, model):
        """
        Rules: the constraints, that UML cannot show, are in the file
        `<name>_constraints.json`, valid for the UML and the ERD, with the
        Word file next to it and the PDF in the documents. The diagram itself
        has no comments.

        Args:
            diagram (Path): Path of the .drawio file.
            model (Path): Path of the JSON model.
        """
        name = f"{diagram.stem}{CONSTRAINTS_SUFFIX}"
        artifacts = diagram.resolve().parent
        data = artifacts / f"{name}.json"
        document = artifacts / f"{name}.docx"
        pdf = ROOT / PATHS["documents"] / f"{name}.pdf"
        command = f"uml_constraints.py draft, then build {data.name}"

        if not data.is_file():
            self.errors.append(f"{data.name} is missing. Create it with the uml-constraints skill ({command})")
            return

        try:
            constraints = ConstraintsModel(data, self.source, self.expected)()
        except RuntimeError as error:
            self.errors.append(str(error))
            return

        for path in (document, pdf):
            if not path.is_file():
                self.errors.append(f"{path.name} is missing. Run: uml_constraints.py build {data.name}")

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
                self.errors.append(f"{item['id']} is missing or changed in {document.name}")

        self.notes.append(f"{len(constraints.items)} constraints, that UML cannot show, are in {document.name}")

    def check_pdf(self, pdf):
        """
        Rules: the PDF has 1 page and shows every name of the diagram.

        Args:
            pdf (Path): Path of the official PDF.
        """
        pages = self.source.read_pdf_pages(pdf)
        content = re.sub(r"\s+", "", "".join(line for page in pages for line in page)).casefold()
        names = [
            *(item["name"] for item in self.uml.classes.values()),
            *(value for item in self.uml.classes.values() for value in item["values"]),
            *(attribute["name"] for item in self.uml.classes.values() for attribute in item["attributes"]),
            *(line["name"] for line in self.uml.associations if line["name"]),
        ]
        missing = sorted({
            name for name in names if re.sub(r"\s+", "", name).casefold() not in content
        })

        if len(pages) != 1:
            self.errors.append(f"The PDF has {len(pages)} pages instead of 1")
        if missing:
            self.errors.append(f"Missing in the PDF: {', '.join(missing)}")

    def report(self):
        lines = [line for line in self.uml.associations if not line["dashed"]]

        print(f"Classes: {len(self.uml.classes)}, associations: {len(lines)}, notes: {len(self.uml.notes)}")

        for label, items in (("Error", self.errors), ("Warning", self.warnings), ("Note", self.notes)):
            for item in items:
                print(f"{label}: {item}")

        print("INVALID" if self.errors else "VALID")


def parse_args():
    parser = argparse.ArgumentParser(description="Validate a UML class diagram.")
    parser.add_argument(
        "diagram", nargs="?", type=Path,
        default=Path(PATHS["artifacts"]) / f"{NAMES['default']}.drawio",
    )
    parser.add_argument("--model", type=Path)
    parser.add_argument("--pdf", type=Path)
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
        validator = UmlValidator(args.erd, args.matrix)

        sys.exit(0 if validator(args.diagram, model, pdf) else 1)
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(error)
        sys.exit(2)
