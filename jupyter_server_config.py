# Start and proxy the Shiny application through Jupyter Server Proxy.

c = get_config()  # noqa: F821

c.ServerProxy.servers = {
    "shiny": {
        "command": [
            "R",
            "--vanilla",
            "-e",
            (
                "shiny::runApp("
                "'/home/pawar', "
                "host='0.0.0.0', "
                "port={port}, "
                "launch.browser=FALSE"
                ")"
            ),
        ],
        "timeout": 120,
        "absolute_url": False,
        "launcher_entry": {
            "title": "Remote Sensing and GIS",
            "enabled": True,
        },
    }
}
