"""
Validation of a Chen ERD against the requirements matrix.
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
SKILLS = SCRIPTS.parents[1]
ROOT = SKILLS.parents[1]
MODIFY_ERD = SKILLS / "modify-erd" / "scripts"

sys.dont_write_bytecode = True
sys.path.insert(0, str(SKILLS / "docx-to-pdf" / "scripts"))
sys.path.insert(0, str(MODIFY_ERD))
sys.path.insert(1, str(SCRIPTS))
sys.path.insert(2, str(SKILLS / "requirements-coverage" / "scripts"))

from classes.ErdModel import ErdModel
from classes.RequirementsMatrix import RequirementsMatrix, read_pdf_pages
from const.general import PATHS, REQUIREMENT_ID
from drawio_erd import CARDINALITY, DrawioErd
from requirements_coverage_model import RequirementsCoverage, erd_elements


class ErdValidator:
    """
    Validation of an ERD against the requirements matrix. It reads the
    finished diagram, not the model, so it also checks hand-made changes.

    Args:
        matrix (str, optional): Matrix used, when the official one is missing.
    """

    def __init__(self, matrix=None):
        self.matrix = RequirementsMatrix(ROOT, matrix)()
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
        self.erd = DrawioErd(diagram)()

        self.check_notation()
        self.check_layout()
        self.check_words()

        if model is not None:
            self.check_model(model)
        else:
            self.check_coverage()

        if pdf is not None:
            self.check_pdf(pdf)

        self.check_requirements_coverage()
        self.report()

        return not self.errors

    def check_notation(self):
        """
        Rules of Chen notation:
        - Every line joins two shapes and has no arrow.
        - Attributes have exactly one owner, relationships at least 2 entities.
        - Strong entity has a key, weak entity has an identifying relationship.
        - Cardinalities are written as 1, 0..1, 1..N, 0..N, ...
        - No entity or shape stands alone.
        """
        erd = self.erd
        neighbours = {identifier: [] for identifier in self.all_ids()}

        if not erd.entities:
            self.errors.append("The diagram has no entities")

        for link in erd.links:
            first, second = erd.kind(link["source"]), erd.kind(link["target"])

            if first is None or second is None:
                self.errors.append(f"A line {link['id']} is not connected to two shapes")
                continue
            if link["arrows"]:
                self.errors.append(f"A line {link['id']} has an arrow, Chen notation has none")
            if {first, second} == {"entity"} or first == second == "relationship":
                self.errors.append(
                    f"{erd.element(link['source'])['name']} - "
                    f"{erd.element(link['target'])['name']}: wrong shapes are joined"
                )

            neighbours[link["source"]].append((link["target"], link["label"]))
            neighbours[link["target"]].append((link["source"], link["label"]))

        for identifier, attribute in erd.attributes.items():
            owners = [other for other, _ in neighbours[identifier] if erd.kind(other) != "attribute"]

            if len(owners) != 1:
                self.errors.append(f"Attribute {attribute['name']} has {len(owners)} owners instead of 1")

        for identifier, relation in erd.relationships.items():
            ends = [(other, label) for other, label in neighbours[identifier] if erd.kind(other) == "entity"]

            if len(ends) < 2:
                self.errors.append(f"Relationship {relation['name']} joins {len(ends)} entities")

            for other, label in ends:
                if not re.fullmatch(CARDINALITY, label or ""):
                    self.errors.append(
                        f"{relation['name']} - {erd.entities[other]['name']}: "
                        f"cardinality '{label}' is missing or wrong"
                    )

            if relation["double"] and not any(erd.entities[other]["double"] for other, _ in ends):
                self.errors.append(f"{relation['name']}: identifying relationship has no weak entity")

        for identifier, entity in erd.entities.items():
            related = [other for other, _ in neighbours[identifier]]
            attributes = [erd.attributes[other] for other in related if other in erd.attributes]
            relations = [erd.relationships[other] for other in related if other in erd.relationships]

            if not relations:
                self.errors.append(f"Entity {entity['name']} has no relationship")
            if not attributes:
                self.warnings.append(f"Entity {entity['name']} has no attributes")
            if entity["double"]:
                if not any(relation["double"] for relation in relations):
                    self.errors.append(f"Weak entity {entity['name']} has no identifying relationship")
            elif not any(item["underlined"] for item in attributes):
                self.errors.append(f"Entity {entity['name']} has no key (underlined attribute)")

        names = [item["name"].casefold() for item in erd.entities.values()]

        for name in sorted({name for name in names if names.count(name) > 1}):
            self.errors.append(f"Entity {name} is drawn more than once")

    def all_ids(self):
        return [*self.erd.entities, *self.erd.relationships, *self.erd.attributes]

    def check_layout(self):
        """
        Shapes must not overlap and the diagram must be of a printable size.
        """
        shapes = [self.erd.element(identifier) for identifier in self.all_ids()]

        for index, first in enumerate(shapes):
            for second in shapes[index + 1:]:
                a, b = first["box"], second["box"]

                if a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]:
                    self.errors.append(f"{first['name']} overlaps {second['name']}")

    def check_words(self):
        """
        Names of entities and relationships should use words of the matrix.
        """
        for item in [*self.erd.entities.values(), *self.erd.attributes.values()]:
            for word in re.findall(r"[^\W\d_]{4,}", item["name"].casefold()):
                if not re.search(rf"\b{re.escape(word[:5])}", self.matrix.text):
                    self.warnings.append(
                        f"{item['name']}: '{word}' is not in the matrix "
                        "(correct only, when it is an assumption)"
                    )

    def check_model(self, path):
        """
        The model gives the evidence for every element, so the diagram must
        be exactly the model and the model must cover the matrix.

        Args:
            path (Path): Path of the JSON model.
        """
        try:
            model = ErdModel(path, self.matrix)()
        except RuntimeError as error:
            self.errors.extend(str(error).splitlines()[1:] or [str(error)])
            return

        drawn = sorted(name.casefold() for name in self.erd.names())
        planned = sorted(name.casefold() for name in model.names())

        for name in sorted(set(planned) - set(drawn)):
            self.errors.append(f"{name}: is in the model, but not in the diagram")
        for name in sorted(set(drawn) - set(planned)):
            self.errors.append(f"{name}: is in the diagram, but not in the model")
        if len(drawn) != len(planned) and set(drawn) == set(planned):
            self.errors.append("Some names are drawn a different number of times than in the model")

        for requirement in self.matrix.ids:
            if requirement in model.not_drawn:
                self.notes.append(f"{requirement}: not drawn - {model.not_drawn[requirement]}")

        for name in self.assumed(model):
            self.warnings.append(f"Assumed, not from the matrix: {name}")

        self.model = model

    def check_requirements_coverage(self):
        """
        Rule: the ERD serves every functional and non-functional requirement,
        as the coverage file of the `requirements-coverage` skill says. Every
        element, that it names, is in the ERD, and a gap of the ERD in a Must
        requirement is an error (in another requirement a warning).
        """
        if getattr(self, "model", None) is None:
            self.notes.append("No model: the coverage of the functional and non-functional requirements is not checked")
            return

        coverage = RequirementsCoverage(ROOT, read_pdf_pages)()
        errors, warnings, notes = coverage.check("erd", erd_elements(self.model.entities, self.model.relationships))
        self.errors.extend(errors)
        self.warnings.extend(warnings)
        self.notes.extend(notes)

    def assumed(self, model):
        items = [*model.entities.values(), *model.relationships]

        for owner in list(items):
            items.extend(owner.get("attributes", []))

        return [f"{item.get('name')} ({item['assumed']})" for item in items if item.get("assumed")]

    def check_coverage(self):
        """
        Without a model the coverage is estimated: a requirement is covered,
        when its text contains a word of any drawn name.
        """
        segments = self.segments()

        for requirement in self.matrix.ids:
            text = segments.get(requirement, "")
            stems = {
                word[:5]
                for name in self.erd.names()
                for word in re.findall(r"[^\W\d_]{4,}", name.casefold())
            }

            if not any(re.search(rf"\b{re.escape(stem)}", text) for stem in stems):
                self.warnings.append(
                    f"{requirement}: no drawn name occurs in its text. Check it by hand."
                )

    def segments(self):
        """
        Returns:
            dict: Text of every requirement, found between two ids.
        """
        text = " ".join(self.matrix.lines)
        found = list(re.finditer(REQUIREMENT_ID, text))

        return {
            match.group(0): re.sub(r"\s+", " ", text[match.end():(
                found[index + 1].start() if index + 1 < len(found) else len(text)
            )]).casefold()
            for index, match in enumerate(found)
        }

    def check_pdf(self, path):
        pages = read_pdf_pages(path)
        content = re.sub(r"\s+", "", "".join(line for page in pages for line in page)).casefold()
        missing = [
            name for name in self.erd.names()
            if re.sub(r"\s+", "", name).casefold() not in content
        ]

        if len(pages) != 1:
            self.errors.append(f"PDF has {len(pages)} pages instead of 1")
        if missing:
            self.errors.append(f"Missing in the PDF: {', '.join(missing)}")

    def report(self):
        erd = self.erd

        print(f"Matrix: {self.matrix.file}")
        print(
            f"Diagram: {len(erd.entities)} entities, {len(erd.relationships)} relationships, "
            f"{len(erd.attributes)} attributes"
        )

        for title, items in (("Notes", self.notes), ("Warnings", self.warnings), ("Errors", self.errors)):
            if items:
                print(f"{title}:")
                print("\n".join(f"- {item}" for item in items))

        print("Result:", "INVALID" if self.errors else "VALID")


def parse_args():
    parser = argparse.ArgumentParser(description="Validate an ERD against the matrix.")
    parser.add_argument("diagram", nargs="?", type=Path)
    parser.add_argument("--model", type=Path)
    parser.add_argument("--pdf", type=Path)
    parser.add_argument("--matrix")

    return parser.parse_args()


def default_paths(args):
    artifacts = ROOT / PATHS["artifacts"]
    documents = ROOT / PATHS["documents"]
    diagram = args.diagram or artifacts / f"{PATHS['erd_name']}.drawio"
    model = args.model or diagram.with_suffix(".json")
    pdf = args.pdf or documents / f"{diagram.stem}.pdf"

    return diagram, model if model.is_file() else None, pdf if pdf.is_file() else None


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="replace")
    args = parse_args()

    try:
        diagram, model, pdf = default_paths(args)

        if not diagram.is_file():
            raise RuntimeError(f"Diagram not found: {diagram}")

        sys.exit(0 if ErdValidator(args.matrix)(diagram, model, pdf) else 1)
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(error)
        sys.exit(2)
