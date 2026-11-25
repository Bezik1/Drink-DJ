PATHS = {
    "matrix_dir": "spec/requirements/documents",
    "matrix_name": "requirements_matrix",
    "artifacts": "spec/conceptual/artifacts",
    "documents": "spec/conceptual/documents",
    "erd_name": "erd",
}

GENERATOR = "modify-erd"
PREVIOUS_GENERATORS = ["requirements-to-erd"]

REQUIREMENT_ID = r"\bR\d{2,}\b"
CARDINALITY = r"(\d+|[A-Z])(\.\.(\d+|[A-Z]))?"

ATTRIBUTE_KINDS = ["key", "partial", "derived", "multivalued", "simple"]

FONT_SIZES = {
    "entity": 20,
    "relationship": 18,
    "attribute": 18,
    "cardinality": 18,
}

SIZES = {
    "entity_width": 170,
    "entity_height": 68,
    "relationship_width": 140,
    "relationship_height": 96,
    "attribute_width": 100,
    "attribute_height": 52,
    "attribute_height_wrapped": 74,
    "attribute_wrap": 140,
    "attribute_distance": 40,
    "gap_x": 70,
    "gap_y": 100,
    "parallel_gap": 10,
    "margin": 150,
}

CLEARANCE = {
    "shape": 16,
    "line": 8,
    "label": 4,
    "attribute_line": 14,
    "attribute_angle": 8,
    "relationship_angle": 8,
}

SEARCH = {
    "spreads_x": [1.5, 1.6, 1.7, 1.85, 2, 2.2, 2.4, 2.7],
    "spreads_y": [1.9, 2, 2.2, 2.4, 2.7, 3, 3.3, 3.7],
    "scales": [1, 1.25, 1.5, 1.8, 2.2, 3, 4, 5, 6],
    "max_clusters": 3,
    "attribute_reach": 0.6,
    "curve": 0.45,
    "attribute_curve": 0.3,
    "recursive_curve": 0.8,
    "straight_angle": 8,
    "curve_pieces": 12,
    "label_positions": [0.5, 0.42, 0.58, 0.34, 0.66, 0.26, 0.74],
    "group_choices": 4,
    "group_separation": 120,
    "angle_step": 5,
    "min_spacing": 16,
    "max_spacing": 90,
    "spacing_step": 2,
    "max_span": 220,
    "attribute_gap": 14,
    "growth_weight": 3000,
    "row_gap": 18,
    "row_step": 20,
    "stagger_penalty": 40,
    "stagger_corridor": 60,
    "shift_weight": 1,
    "fan_penalty": 80,
    "arc_penalty": 60,
    "arc_min_items": 3,
    "arc_span": 150,
    "arc_growth": 240,
    "arc_step": 20,
    "sides": {270: (0, -1), 90: (0, 1), 180: (-1, 0), 0: (1, 0)},
}

PAPERS = {
    "A4": (806, 559),
    "A3": (1155, 806),
    "A2": (1648, 1155),
}

PX_TO_PT = 0.75

PDF_PAGE = {
    "px_to_pt": 0.72,
    "tolerance": 0.01,
    "units": {"cm": 72 / 2.54, "mm": 72 / 25.4, "in": 72, "pt": 1},
}
MIN_PRINTED_FONT = 6

BASE_STYLE = "whiteSpace=wrap;html=1;"

STYLES = {
    "entity": f"rounded=1;arcSize=8;{BASE_STYLE}",
    "weak_entity": f"shape=ext;margin=4;double=1;rounded=1;arcSize=8;{BASE_STYLE}",
    "relationship": f"rhombus;{BASE_STYLE}",
    "identifying": f"shape=rhombus;double=1;perimeter=rhombusPerimeter;{BASE_STYLE}",
    "attribute": f"rounded=1;arcSize=50;perimeter=ellipsePerimeter;{BASE_STYLE}",
    "key": f"rounded=1;arcSize=50;perimeter=ellipsePerimeter;fontStyle=4;{BASE_STYLE}",
    "derived": f"rounded=1;arcSize=50;perimeter=ellipsePerimeter;dashed=1;{BASE_STYLE}",
    "multivalued": f"shape=ext;margin=4;double=1;rounded=1;arcSize=50;perimeter=ellipsePerimeter;{BASE_STYLE}",
    "line": "endArrow=none;rounded=0;curved=0;strokeColor=#777777;",
    "curve": "endArrow=none;rounded=0;curved=1;strokeColor=#777777;",
    "cardinality": "edgeLabel;html=1;align=center;verticalAlign=middle;resizable=0;labelBackgroundColor=none;",
}
