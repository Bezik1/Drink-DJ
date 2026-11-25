import importlib.util
from pathlib import Path

from const.general import NAMES, PATHS

SKILLS = Path(__file__).resolve().parents[3]
LOADERS = {}


def uml_module(module):
    """
    Imports a module of the `modify-uml` skill. Both skills have the packages
    `classes`, `const` and `utils`, so the module is imported with the loader
    of `modify-uml`, that keeps them apart.

    Args:
        module (str): Name of the module, for example "classes.UmlRouter".

    Returns:
        module: Imported module.
    """
    scripts = SKILLS / NAMES["uml_skill"] / PATHS["scripts"]
    helper = scripts / "utils" / "skills.py"

    if "uml" not in LOADERS:
        if not helper.is_file():
            raise RuntimeError(
                f"The {NAMES['uml_skill']} skill is missing in {SKILLS}. It is needed to read the UML."
            )

        spec = importlib.util.spec_from_file_location("modify_uml_skill_loader", helper)
        loader = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(loader)
        LOADERS["uml"] = loader

    return LOADERS["uml"].load_module(scripts, module)
