"""Usage:

    $ fab monkeygrade deploy

"""

import os
import datetime
from fabric.api import *
from fabric.contrib.project import rsync_project
from fabric.contrib.files import exists
from fabric.utils import abort


@task
def monkeygrade():
    env.hosts = ['ekinek.pair.com']
    env.user = 'ianjones'
    env.install_dir = '/usr/home/ianjones/public_html/monkeygrade/beamap'


@task
def deploy():
    if os.getcwd() != os.path.dirname(os.path.abspath(__file__)):
        abort("must run fab from the root of the project")
    rsync_project(
        local_dir="web/",
        remote_dir=env.install_dir,
        exclude=['.hg*', '.git*', '.DS_Store'],
    )
