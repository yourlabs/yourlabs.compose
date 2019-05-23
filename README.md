Deploying a docker-compose.yml to a server
------------------------------------------

From command line:

    bigsudo yourlabs.compose home=/home/yourproject compose=docker-compose.yml
    bigsudo yourlabs.compose home=/home/yourproject compose=http://.../docker-compose.yml

From an ansible role if you want to wrap it in more stuff:

    - name: Ensure docker was setup once on this host
      include_role: name=yourlabs.compose
      vars:
        compose: ./docker-compose.yml
        home: /etc/nginx

Don't forget to add the role to your requirements.yml.
