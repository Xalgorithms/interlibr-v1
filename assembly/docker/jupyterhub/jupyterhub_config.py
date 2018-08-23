from oauthenticator.github import GitHubOAuthenticator

# jupyterhub_config.py file
c = get_config()

import os
pjoin = os.path.join

runtime_dir = os.path.join('/srv/jupyterhub')
#ssl_dir = pjoin(runtime_dir, 'ssl')
#if not os.path.exists(ssl_dir):
#    os.makedirs(ssl_dir)

# Allows multiple single-server per user
c.JupyterHub.allow_named_servers = True

# https on :443
# c.JupyterHub.port = 443
# c.JupyterHub.ssl_key = pjoin(ssl_dir, 'ssl.key')
# c.JupyterHub.ssl_cert = pjoin(ssl_dir, 'ssl.cert')

# put the JupyterHub cookie secret and state db
# in /var/run/jupyterhub
c.JupyterHub.cookie_secret_file = pjoin(runtime_dir, 'cookie_secret')
c.JupyterHub.db_url = pjoin(runtime_dir, 'jupyterhub.sqlite')
# or `--db=/path/to/jupyterhub.sqlite` on the command-line

# use GitHub OAuthenticator for local users
c.JupyterHub.authenticator_class = 'oauthenticator.LocalGitHubOAuthenticator'
c.GitHubOAuthenticator.oauth_callback_url = os.environ['OAUTH_CALLBACK_URL']

# create system users that don't exist yet
c.LocalAuthenticator.create_system_users = True

# specify users and admin
c.Authenticator.whitelist = {'karfai'}
c.Authenticator.admin_users = {'karfai'}

# start single-user notebook servers in ~/assignments,
# with ~/assignments/Welcome.ipynb as the default landing page
# this config could also be put in
# /etc/jupyter/jupyter_notebook_config.py
#c.Spawner.notebook_dir = '/notebooks/'
#c.Spawner.args = ['--NotebookApp.default_url=/notebooks/Welcome.ipynb']

c.DockerSpawner.use_internal_ip = True
network_name = os.getenv('DOCKER_SPAWNER_NETWORK_NAME')
if network_name:
    c.DockerSpawner.network_name = network_name

# The docker instances need access to the Hub, so the default loopback port doesn't work:
from jupyter_client.localinterfaces import public_ips
c.JupyterHub.hub_ip = public_ips()[0]
c.JupyterHub.port = 8000

c.JupyterHub.spawner_class = 'dockerspawner.DockerSpawner'
