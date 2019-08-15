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
            'docker_compose_external_config': self.external_config,
            'docker_compose_rewrite': self.rewrite,
            'docker_compose_env': self.env,
            'allenv': self.allenv,
        }

    def rewrite(self, compose_contents, hostvars, available_networks):
        config = yaml.safe_load(compose_contents)
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

                if value:
                    service[key] = value

                elif key in service:
                    service.pop(key)

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

            if isinstance(network['external'], dict):
                result.append(network['external'].get('name', name))
            else:
                result.append(name)

        return result

    def external_config(self, compose_content):
        config = yaml.safe_load(compose_content)

        result = dict()
        for name, service in config.get('services', {}).items():
            for var, val in service.get('labels', {}).items():
                if not var.startswith('io.yourlabs.compose.'):
                    continue
                var = var[len('io.yourlabs.compose.'):]
                if var == 'mkdir':
                    result[var] = []
                    for mkdir in val.split(','):
                        parts = mkdir.split(':')
                        result[var].append(dict(
                            path=parts[0],
                            owner=parts[1],
                            group=parts[2],
                            mode=parts[3],
                        ))
                else:
                    result[var] = val
        return result

    def allenv(self, *args):
        return dict(os.environ)

    def env(self, compose_content):
        config = yaml.safe_load(compose_content)

        result = []
        for name, service in config.get('services', {}).items():
            for key, value in service.get('environment', dict()).items():
                if key in os.environ:
                    result.append(f'{key}={os.getenv(key)}')

        return '\n'.join(result)
