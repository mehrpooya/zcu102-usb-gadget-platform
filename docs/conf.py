# docs/conf.py
# Sphinx configuration for the ZCU102 USB Gadget Platform documentation.
# Uses the sphinx-rtd-theme and MyST-Parser so .md files are first-class citizens.

import os
import sys

# -- Project information -----------------------------------------------------
project   = "ZCU102 USB Gadget Platform"
author    = "Ali Mehrpooya — Smart Internet Lab (HPN Group), University of Bristol"
copyright = "2026, Ali Mehrpooya"
release   = "1.0.0"
version   = "1.0"

# -- General configuration ---------------------------------------------------
extensions = [
    "myst_parser",           # Markdown support
    "sphinx.ext.autosectionlabel",  # Auto-generate section labels
    "sphinx_copybutton",     # Copy button on all code blocks
    "sphinx.ext.githubpages",
]

source_suffix = {
    ".rst": "restructuredtext",
    ".md":  "markdown",
}

master_doc = "index"
language   = "en"
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store", "requirements.txt"]

# MyST options
myst_enable_extensions = [
    "colon_fence",    # ::: admonition syntax
    "deflist",
    "tasklist",
    "attrs_inline",
]
myst_heading_anchors = 3

# -- HTML output options -----------------------------------------------------
html_theme = "sphinx_rtd_theme"

html_theme_options = {
    "logo_only":             False,
    "prev_next_buttons_location": "bottom",
    "style_external_links":  True,
    "collapse_navigation":   False,
    "sticky_navigation":     True,
    "navigation_depth":      4,
    "includehidden":         True,
    "titles_only":           False,
}

html_context = {
    "display_github": True,
    "github_user":    "mehrpooya",
    "github_repo":    "zcu102-usb-gadget-platform",
    "github_version": "main",
    "conf_py_path":   "/docs/",
}

html_static_path = ["_static"]
html_css_files   = ["custom.css"]

html_title = "ZCU102 USB Gadget Platform"
html_short_title = "ZCU102 Gadget"

# Suppress the "document isn't included in any toctree" warning for the tutorial
# sub-sections (they are all pulled in via the main toctree).
suppress_warnings = ["autosectionlabel.*"]

# -- copybutton config -------------------------------------------------------
copybutton_prompt_text = r"\$ |# |>>> "
copybutton_prompt_is_regexp = True
