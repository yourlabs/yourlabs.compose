#!/usr/bin/python
import json
import os
import subprocess
import yaml

from ansible import errors


class FilterModule(object):
    def filters(self):
        return {
            'docker_compose_env_file': self.env_file,
            'docker_compose_external_networks': self.external_networks,
            'docker_compose_rewrite': self.rewrite,
        }

    def env_file(self, compose_path):
        with open(compose_path, 'r') as f:
            config = yaml.safe_load(f)

        result = []
        for name, service in config.get('services', {}).items():
            if 'environment' not in service:
                continue
            env = service['environment']

            if isinstance(env, dict):
                continue

            for item in env:
                var = item.split('=')[0]
                if var not in os.environ:
                    continue

                val = os.getenv(var).replace('"', '\\"')
                result.append(f'{var}="{val}"')

        return '\n'.join(result)

    def rewrite(self, compose_path, hostvars, available_networks):
        with open(compose_path, 'r') as f:
            config = yaml.safe_load(f)

        networks = hostvars.get('networks', '').split(',')
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

            for network in networks:
                if not network:
                    continue

                config.setdefault('networks', {})
                config['networks'][name] = dict(external=dict(name=network))

            for network in service.get('networks', []):
                if network in config.get('networks', {}).keys():
                    continue

                if network not in available_networks + external_networks:
                    continue

                config.setdefault('networks', {})
                config['networks'][network] = dict(external=dict(name=network))

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
