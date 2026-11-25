import importlib
import sys
from pathlib import Path

ISOLATED = ["classes", "const", "utils"]


def load_module(scripts, module):
    """
    Imports a module of another skill. The packages `classes`, `const` and
    `utils` have the same names in every skill, so the other skill gets its
    own import and the packages of the caller are put back afterwards.

    Args:
        scripts (Path): Folder `scripts` of the other skill.
        module (str): Name of the module, for example "classes.ErdModel".

    Returns:
        module: Imported module.
    """
    saved = {
        name: sys.modules.pop(name)
        for name in list(sys.modules)
        if name.split(".")[0] in ISOLATED
    }
    sys.path.insert(0, str(scripts))

    try:
        return importlib.import_module(module)
    except ImportError as error:
        raise RuntimeError(f"Cannot import {module} from {Path(scripts).parent.name}: {error}")
    finally:
        sys.path.remove(str(scripts))

        for name in [name for name in sys.modules if name.split(".")[0] in ISOLATED]:
            del sys.modules[name]

        sys.modules.update(saved)
