from pathlib import Path

app = Path("/Applications/传感星云.app")

volume_name = "传感星云 0.1.1"
format = "UDZO"
size = "24M"
files = [str(app)]
symlinks = {"应用程序": "/Applications"}

badge_icon = str(app)
background = str(Path.cwd() / "Resources/InstallerBackground.svg.png")
background_color = "#0b0e1d"
window_rect = ((180, 140), (700, 440))
icon_size = 96
text_size = 13
icon_locations = {
    "传感星云.app": (198, 202),
    "应用程序": (502, 202),
}
hide_extensions = ["传感星云.app"]
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
default_view = "icon-view"
arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
