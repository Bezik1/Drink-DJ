"""
Coverage of the functional and non-functional requirements by the conceptual
design, with its check for every design level.
"""
import hashlib
import json
import re

from requirements_coverage_const import BLOCKING, ID_PATTERN, LEVELS, PATHS, PREFIXES, SIGNIFICANCES, STATUSES


def snake(text):
    return "_".join(word.lower() for word in re.findall(r"[A-Za-z0-9]+", text))


def signature(name, ends):
    return f"{PREFIXES['relationship']}{name}:{'/'.join(sorted(ends))}"


def erd_elements(entities, relationships):
    """
    Names the elements of an ERD model, as the coverage file uses them.

    Rules:
    - An entity is its key, for example `schedule_stop`.
    - An attribute is `entity.attribute` in snake case, for example
      `schedule_stop.arrival_time`. An attribute of a relationship has the
      name of the relationship in snake case, for example `consists_of.index`.
    - A relationship is `rel:<name>:<entity>/<entity>`, with sorted keys.

    Args:
        entities (dict[]): Entities of the ERD model.
        relationships (dict[]): Relationships of the ERD model.

    Returns:
        set[str]: Names of the elements.
    """
    names = set()

    for key, entity in entities.items():
        names.add(key)
        names.update(f"{key}.{snake(item['name'])}" for item in entity.get("attributes", []))

    for relation in relationships:
        names.add(signature(relation["name"], relation["ends"]))
        names.update(f"{snake(relation['name'])}.{snake(item['name'])}" for item in relation.get("attributes", []))

    return names


def uml_elements(classes, associations, constraints):
    """
    Names the elements of a UML model, with the names of the ERD, that it
    comes from, so one coverage file serves every level. An operation is
    `class.operation()`, and it exists only at the UML level.

    Args:
        classes (dict[]): Classes of the UML model.
        associations (dict[]): Associations of the UML model.
        constraints (dict[]): Constraints of the `uml-constraints` skill.

    Returns:
        set[str]: Names of the elements, and `constraint:<id>` of every constraint.
    """
    names = set()

    for key, item in classes.items():
        if item.get("stereotype"):
            continue

        base = item.get("entity") or key
        names.add(base)
        names.update(
            f"{base}.{snake(attribute['erd']) if attribute.get('erd') else attribute['name']}"
            for attribute in item.get("attributes", [])
        )
        names.update(f"{base}.{operation['name']}()" for operation in item.get("operations", []))

    for item in associations:
        names.add(PREFIXES["relationship"] + item["erd"] if item.get("erd") else signature(item["name"], item["ends"]))

    names.update(f"{PREFIXES['constraint']}{item['id']}" for item in constraints)

    return names


def relational_elements(tables, constraint_ids):
    """
    Names the elements of a relational model, with the names of the UML, that
    it comes from.

    Rules:
    - A table is the key of its UML class, a column the path of its UML
      attribute (`class.attribute`), and a derived attribute, that is not
      stored, counts too, because it is calculated.
    - A foreign key or a junction table is the relationship of its association.
    - A constraint is every UML constraint, that the relational constraints
      carry over or cover, and every relational constraint.

    Args:
        tables (dict[]): Tables of the relational model.
        constraint_ids (str[]): Ids of these constraints.

    Returns:
        set[str]: Names of the elements.
    """
    names = set()

    for table in tables.values():
        if table.get("class"):
            names.add(table["class"])
        if table.get("association"):
            names.add(PREFIXES["relationship"] + table["association"])

        for column in table.get("columns", []):
            if column.get("uml"):
                names.add(".".join(column["uml"].split(".")[:2]))

        names.update(item["uml"] for item in table.get("omitted", []))
        names.update(
            PREFIXES["relationship"] + item["association"]
            for item in table.get("foreign_keys", []) if item.get("association")
        )

    names.update(f"{PREFIXES['constraint']}{item}" for item in constraint_ids)

    return names


class RequirementsCoverage:
    """
    The JSON file, that says how the conceptual design serves every functional
    and non-functional requirement, and its check for one design level.

    Rules:
    - The file belongs to the current official documents of the requirements
      (checksums), and has one entry for every requirement id in them.
    - `covered`: the design serves it, and `elements` name what serves it.
    - `gap`: the design does not serve it yet. Every gap names the `level`,
      that must change (`erd`, `uml` or `relational`), and the `text` of what is
      missing. A gap of a Must requirement makes that level invalid, and of any
      other requirement it is a warning.
    - `not_applicable`: the requirement is not about data (a user interface,
      performance, hosting), and `reason` says so.
    - Every element must exist at the checked level. Constraints are checked
      from the UML up, because an ERD has none.

    Args:
        root (Path): Root of the repository.
        read_pdf_pages (callable): Reader of the text of a PDF.
        path (Path, optional): Path of the coverage file. Default: the official one.
    """

    def __init__(self, root, read_pdf_pages, path=None):
        self.root = root
        self.read_pdf_pages = read_pdf_pages
        self.path = path or root / PATHS["coverage"]
        self.errors = []

    def __call__(self):
        """
        Reads the documents of the requirements and the coverage file.

        Returns:
            RequirementsCoverage: Coverage with its structural errors.
        """
        self.sources = {}

        for kind in ("functional", "non_functional"):
            document = self.root / PATHS[kind]

            if not document.is_file():
                raise RuntimeError(f"Requirements not found: {document}")

            text = " ".join(line for page in self.read_pdf_pages(document) for line in page)
            self.sources[kind] = {
                "file": PATHS[kind],
                "sha256": hashlib.sha256(document.read_bytes()).hexdigest(),
                "ids": sorted(set(re.findall(ID_PATTERN, text)), key=self.order),
            }

        self.ids = [item for kind in self.sources.values() for item in kind["ids"]]
        self.items = []

        if not self.path.is_file():
            self.errors.append(
                f"{self.path.name} is missing. Write it with the requirements-coverage skill "
                "(requirements_coverage.py draft, then review it)"
            )
            return self

        self.data = json.loads(self.path.read_text(encoding="utf-8"))
        self.items = self.data.get("requirements", [])
        self.check_sources()
        self.check_items()

        return self

    @staticmethod
    def order(identifier):
        return identifier.startswith("N"), int(re.sub(r"\D", "", identifier)), identifier

    def check_sources(self):
        for kind, source in self.sources.items():
            if self.data.get("sources", {}).get(kind, {}).get("sha256") != source["sha256"]:
                self.errors.append(
                    f"{source['file']} changed. Review the coverage of the requirements and write its checksum again"
                )

    def check_items(self):
        found = [item.get("id") for item in self.items]

        for identifier in self.ids:
            if found.count(identifier) != 1:
                self.errors.append(f"{identifier}: the requirement has {found.count(identifier)} entries instead of 1")

        for identifier in sorted(set(found) - set(self.ids), key=lambda item: str(item)):
            self.errors.append(f"{identifier}: it is not a requirement of the official documents")

        for item in self.items:
            name = item.get("id", "?")
            status = item.get("status")

            if status not in STATUSES:
                self.errors.append(f"{name}: status must be one of {STATUSES}, not {status}")
            if item.get("significance") not in SIGNIFICANCES:
                self.errors.append(f"{name}: significance must be one of {SIGNIFICANCES}")
            if status == "covered" and (not item.get("elements") or item.get("gaps")):
                self.errors.append(f"{name}: a covered requirement names its elements and has no gaps")
            if status == "gap" and not item.get("gaps"):
                self.errors.append(f"{name}: a gap names what is missing in 'gaps'")
            if status == "not_applicable" and not item.get("reason"):
                self.errors.append(f"{name}: give the reason, why it is not about the data design")

            for gap in item.get("gaps", []):
                if gap.get("level") not in LEVELS or not gap.get("text"):
                    self.errors.append(f"{name}: every gap has a level ({', '.join(LEVELS)}) and a text")

            for column, length in item.get("lengths", {}).items():
                if not isinstance(length, int):
                    self.errors.append(f"{name}: the length of {column} must be a number")

    def check(self, level, elements, types=None):
        """
        Checks the coverage for one design level.

        Args:
            level (str): "erd", "uml" or "relational".
            elements (set[str]): Names of the elements of that level.
            types (dict[], optional): SQL type of every "Table.column", for the
                lengths, that the relational model must keep.

        Returns:
            tuple[str[], str[], str[]]: Errors, warnings and notes.
        """
        errors, warnings = list(self.errors), []
        title = LEVELS[level]

        for item in self.items:
            name = item.get("id", "?")

            for element in item.get("elements", []):
                if level == "erd" and element.startswith(PREFIXES["constraint"]):
                    continue
                if level != "uml" and element.endswith("()"):
                    continue
                if element not in elements:
                    errors.append(f"{name}: {element} is not in the {title}, but the requirement needs it")

            for gap in item.get("gaps", []):
                if gap.get("level") != level:
                    continue

                message = f"{name} ({item.get('significance')}) is not met by the {title}: {gap.get('text')}"
                (errors if item.get("significance") in BLOCKING else warnings).append(message)

            if level == "relational" and types is not None:
                for column, length in item.get("lengths", {}).items():
                    match = re.search(r"\((\d+)\)", types.get(column, ""))

                    if column not in types or not match or int(match.group(1)) < length:
                        errors.append(f"{name}: {column} must store at least {length} characters")

        return errors, warnings, [self.summary()] if self.items else []

    def summary(self):
        counts = {status: sum(item.get("status") == status for item in self.items) for status in STATUSES}

        return (
            f"Requirements ({len(self.items)}): {counts['covered']} covered, {counts['gap']} with gaps, "
            f"{counts['not_applicable']} not about the data design"
        )

    def save(self):
        self.path.write_text(json.dumps(self.data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
