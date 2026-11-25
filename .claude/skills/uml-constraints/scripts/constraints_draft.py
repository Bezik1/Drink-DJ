"""
First version of the constraints of a UML class diagram, written from the ERD.
"""
import re
from collections import Counter

from classes.UmlDraft import UmlDraft
from constraints_const import MARKER


class ConstraintsDraft:
    """
    Candidates of the constraints, that a UML class diagram cannot show.

    Rules:
    - A weak entity, whose identifier is not drawn completely (no composition,
      or several identifying relationships), gets an `identity` constraint.
    - An assumption of the ERD with "Chen notation cannot show" gives a `rule`
      without that sentence, because UML cannot show it either.
    - An assumption of the ERD about a derived attribute gives a `derivation`.
    - Everything else of the ERD is drawn in the UML, so it is not here.

    Args:
        source (ErdSource): ERD and matrix.
        uml (UmlModel): Validated model of the UML.
    """

    def __init__(self, source, uml):
        self.source = source
        self.erd = source.model
        self.uml = uml
        self.helper = UmlDraft(source)
        self.items = []

    def __call__(self):
        """
        Builds the candidates. The agent reviews them and removes everything,
        that the UML shows.

        Returns:
            dict[]: Description of the constraints.
        """
        self.identities()
        self.rules()
        self.derivations()

        for number, item in enumerate(self.items, 1):
            item["id"] = f"C{number:02d}"

        return {
            "uml": {"file": self.uml.path.as_posix()},
            "erd": {"file": self.source.file, "sha256": self.source.sha256},
            "constraints": [
                {"id": item.pop("id"), **item} for item in self.items
            ],
        }

    def add(self, kind, classes, text, sources):
        if any(item["text"] == text for item in self.items):
            return

        self.items.append({"kind": kind, "classes": classes, "text": text, "from": sources})

    def identities(self):
        owners = self.helper.find_owners()

        for key, entity in self.erd.entities.items():
            if not entity.get("weak"):
                continue

            relations = [
                item for item in self.erd.relationships
                if item.get("identifying") and owners[self.signature(item)][1] == key
            ]
            composed = any(
                item.get("kind") == "composition" and item.get("whole") != key and key in item["ends"]
                for item in self.uml.associations
            )

            if composed and len(relations) < 2:
                continue

            parts = [
                (name, relation["name"])
                for relation in relations
                for name in self.helper.keys_of(owners[self.signature(relation)][0])
            ]
            counts = Counter(name for name, _ in parts)
            names = [f"{name} ({via})" if counts[name] > 1 else name for name, via in parts]
            names.extend(
                item["name"] for item in entity.get("attributes", []) if item.get("kind") == "partial"
            )

            if names:
                head = ", ".join(names[:-1])
                listed = f"{head} and {names[-1]}" if head else names[-1]

                self.add("identity", [key], f"{entity['name']} is identified by {listed}.", entity.get("from", []))

    @staticmethod
    def signature(relation):
        return f"{relation['name']}:{'/'.join(sorted(relation['ends']))}"

    def split(self, assumption):
        match = re.match(r"((?:R\d+(?:, )?)+): (.*)", assumption, re.S)

        if match:
            return match.group(1).split(", "), match.group(2)

        return [], assumption

    def sentences(self, text):
        return [item for item in re.split(r"(?<=\.) ", text) if item]

    def mentioned(self, text):
        found = []

        for key, entity in self.erd.entities.items():
            names = [entity["name"]] + [item["name"] for item in entity.get("attributes", [])]

            if any(re.search(rf"\b{re.escape(name)}", text, re.I) for name in names):
                found.append(key)

        first = self.helper.first_mentioned(text)

        return sorted(found, key=lambda key: key != first)

    def rules(self):
        for assumption in self.erd.assumptions:
            if MARKER not in assumption.casefold():
                continue

            sources, text = self.split(assumption)
            kept = [item for item in self.sentences(text) if MARKER not in item.casefold()]

            if kept:
                joined = " ".join(kept)

                self.add("rule", self.mentioned(joined), joined, sources)

    def derivations(self):
        for key, entity in self.erd.entities.items():
            for attribute in entity.get("attributes", []):
                if attribute.get("kind") != "derived":
                    continue

                for assumption in self.erd.assumptions:
                    sources, text = self.split(assumption)

                    if re.search(rf"\b{re.escape(attribute['name'])}\b", text, re.I) and MARKER not in text.casefold():
                        self.add("derivation", [key], text, sources)
