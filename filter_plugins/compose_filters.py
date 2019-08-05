#!/usr/bin/python
import json
import os
import subprocess
import yaml

from ansible import errors


class FilterModule(object):
    def filters(self):
        return {
            'docker_compose_external_networks': self.external_networks,
            'docker_compose_rewrite': self.rewrite,
        }

    def rewrite(self, compose_path, hostvars, available_networks):
        with open(compose_path, 'r') as f:
            config = yaml.safe_load(f)

        external_networks = []
        for name, service in config.get('services', {}).items():
            for key, value in hostvars.items():
                if not key.startswith('compose_' + name + '_'):
                    continue

                key = key[len('compose_' + name + '_'):]

                if key == 'networks' and isinstance(value, str):
                    value = value.split(',')
                    external_networks += value

                if key in service and isinstance(service[key], list):
                    value += service[key]

                service[key] = value

            for network in service.get('networks', []):
                if network in config.get('networks', {}).keys():
                    continue

                if network not in available_networks + external_networks:
                    continue

                config.setdefault('networks', {})
                config['networks'][network] = dict(external=dict(name=network))

            environment = service.get('environment', [])
            if isinstance(environment, list):
                new_environment = []
                for line in environment:
                    var = line.split('=')[0]
                    if var in os.environ:
                        val = os.getenv(var).replace('"', '\\"')
                        new_environment.append(f'{var}="{val}"')
                    else:
                        new_environment.append(line)
                service['environment'] = new_environment

        return yaml.dump(config)

    def external_networks(self, compose_content):
        config = yaml.safe_load(compose_content)

        result = []
        for name, network in config.get('networks', {}).items():
            if not isinstance(network, dict):
                continue

            if not network.get('external', False):
                continue

            result.append(network['external'].get('name', name))

        return result
