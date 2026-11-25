PATHS = {
    "erd_model": "spec/conceptual/artifacts/erd.json",
    "artifacts": "spec/conceptual/artifacts",
    "documents": "spec/conceptual/documents",
    "skills": ".claude/skills",
    "scripts": "scripts",
}

NAMES = {
    "default": "uml_class_diagram",
    "generator": "modify-uml",
    "erd_skills": ["modify-erd", "requirements-to-erd"],
    "uml_skill": "modify-uml",
    "validator": "validate-uml",
    "word_skill": "modify-word",
    "comments": "_comments",
    "pdf_skill": "docx-to-pdf",
}

PRIMITIVES = ["String", "Integer", "Decimal", "Boolean", "Date", "Time", "DateTime"]

STEREOTYPES = ["enumeration", "dataType"]

PATTERNS = {
    "multiplicity": r"\d+(\.\.(\d+|\*))?|\*",
    "snake": r"[a-z][a-z0-9]*(_[a-z0-9]+)*",
    "attribute": r"([+\-#~]) (/?)([a-z][a-z0-9_]*) : ([A-Za-z][A-Za-z0-9 ]*?)( \[(\d+\.\.(?:\d+|\*)|\*)\])?",
    "operation": r"([+\-#~]) ([a-z][a-z0-9_]*)\((.*)\)( : ([A-Za-z][A-Za-z0-9 ]*))?",
    "requirement": r"\bR\d{2,}\b",
    "enumeration": r"([a-z][a-z ]*?) value can be equal to ((?:(?:[“\"])[^”\"]+(?:[”\"]),? ?(?:or )?)+)",
    "enumeration_value": r"[“\"]([^”\"]+)[”\"]",
    "composite": r"{name} consists of ([^.]+)\.",
}

TYPE_RULES = [
    (r"\b(postal|zip|email|password|name|title|description|location|picture|phone|street|city|country|surname|mode|type)\b", "String"),
    (r"\b(public|is|has|active|enabled)\b", "Boolean"),
    (r"\b(price|weight|load|value|amount|cost|rate)\b", "Decimal"),
    (r"\b(date)\b", "Date"),
    (r"\b(time)\b", "Time"),
    (r"\b(code|number|index|position|quantity|capacity|count|likes|identifier|id)\b", "Integer"),
]
DEFAULT_TYPE = "String"

SIZES = {
    "char_width": 7.4,
    "header_height": 26,
    "line_height": 18,
    "padding": 14,
    "min_width": 150,
    "operations_height": 18,
    "gap_x": 170,
    "gap_y": 120,
    "margin": 150,
}

FONT_SIZES = {
    "class": 12,
    "label": 12,
}

BASE_STYLE = "html=1;whiteSpace=wrap;"

STYLES = {
    "class": (
        "swimlane;fontStyle=1;align=center;verticalAlign=top;childLayout=stackLayout;"
        "horizontal=1;startSize=26;horizontalStack=0;resizeParent=1;resizeParentMax=0;"
        "resizeLast=0;collapsible=0;marginBottom=0;whiteSpace=wrap;html=1;"
    ),
    "attributes": "text;strokeColor=none;fillColor=none;align=left;verticalAlign=top;spacingLeft=4;spacingRight=4;overflow=hidden;rotatable=0;points=[[0,0.5],[1,0.5]];portConstraint=eastwest;whiteSpace=wrap;html=1;",
    "divider": "line;strokeWidth=1;fillColor=none;align=left;verticalAlign=middle;spacingTop=-1;spacingLeft=3;spacingRight=3;rotatable=0;labelPosition=right;points=[];portConstraint=eastwest;strokeColor=inherit;",
    "operations": "text;strokeColor=none;fillColor=none;align=left;verticalAlign=top;spacingLeft=4;spacingRight=4;overflow=hidden;rotatable=0;points=[[0,0.5],[1,0.5]];portConstraint=eastwest;whiteSpace=wrap;html=1;",
    "association": "endArrow=none;startArrow=none;html=1;rounded=0;strokeColor=#000000;",
    "composition": "endArrow=diamondThin;endFill=1;endSize=16;startArrow=none;html=1;rounded=0;strokeColor=#000000;",
    "attachment": "endArrow=none;dashed=1;html=1;rounded=0;strokeColor=#000000;",
    "label": "edgeLabel;html=1;align=center;verticalAlign=middle;resizable=0;labelBackgroundColor=none;",
}

ROUTING = {
    "stub": 24,
    "outer": 60,
    "clearance": 10,
    "own_margin": 2,
    "bend": 60,
    "length": 0.05,
    "crossing": 45,
    "overlap": 400,
    "side": 18,
    "port_step": 70,
    "corner": 14,
    "shifts": [0, -16, 16, -32, 32],
    "loop": 48,
}

LABELS = {
    "end": 8,
    "side": 14,
    "diamond": 22,
}
