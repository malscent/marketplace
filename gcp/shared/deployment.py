import naming


def GenerateConfig(context):
    config = {}
    config['resources'] = []
    config['outputs'] = []

    runtimeconfigName = naming.RuntimeConfigName(context)
    runtimeconfig = {
        'name': runtimeconfigName,
        'type': 'runtimeconfig.v1beta1.config',
        'properties': {
            'config': runtimeconfigName
        }
    }
    config['resources'].append(runtimeconfig)
    config['resources'].append(GenerateCouchbaseUserPasswordVariable(context, runtimeconfigName, context.properties['couchbasePassword']))
    config['resources'].append(GenerateCouchbaseUserUsernameVariable(context, runtimeconfigName, context.properties['couchbaseUsername']))
    for cluster in context.properties['clusters']:
        clusterName = cluster['cluster']
        clusterResourceName = naming.ClusterName(context, clusterName)

        clusterJSON = {
            'name': clusterResourceName,
            'type': 'cluster.py',
            'properties': {
                'runtimeconfigName': runtimeconfigName,
                'serverVersion': context.properties['serverVersion'],
                'syncGatewayVersion': context.properties['syncGatewayVersion'],
                'couchbaseUsername': context.properties['couchbaseUsername'],
                'couchbasePassword': context.properties['couchbasePassword'],
                'license': context.properties['license'],
                'cluster': cluster['cluster'],
                'region': cluster['region'],
                'groups': cluster['groups'],
            }
        }
        config['resources'].append(clusterJSON)

        for group in cluster['groups']:
            groupName = group['group']
            outputName = naming.ExternalIpOutputName(context, clusterName, groupName)

            createActionName = naming.ExternalIpVariableCreateActionName(context, clusterName, groupName)

            config['outputs'].append({
                'name': outputName,
                'value': '$(ref.%s.text)' % createActionName
            })

    firewall = {
        'name': naming.FirewallName(context),
        'type': 'compute.v1.firewall',
        'properties': {
            'sourceRanges': ['0.0.0.0/0'],
            'allowed': [{
                'IPProtocol': 'tcp',
                'ports': ['4369', '8091-8096', '9100-9105', '9110-9118', '9120-9122', '9130' '9140', '9999', '11207',
                          '11209-11211', '11207', '21100', '11206-11207', '18091-18096','19130','21150']
            }]
        }
    }
    config['resources'].append(firewall)

    return config


def GenerateCouchbaseUserPasswordVariable(context, runtimeconfigName, password):
    project = context.env['project']
    variable = {
        'name': naming.PasswordVariableName(context),
        'type': 'runtimeconfig.v1beta1.variable',
        'properties': {
            'parent': 'projects/%s/configs/%s' % (project, runtimeconfigName),
            'variable': 'cb-password',
            'text': password
        },
        'metadata': {
            'dependsOn': [runtimeconfigName]
        }
    }
    return variable

def GenerateCouchbaseUserUsernameVariable(context, runtimeconfigName, username):
    project = context.env['project']
    variable = {
        'name': naming.UsernameVariableName(context),
        'type': 'runtimeconfig.v1beta1.variable',
        'properties': {
            'parent': 'projects/%s/configs/%s' % (project, runtimeconfigName),
            'variable': 'cb-username',
            'text': username
        },
        'metadata': {
            'dependsOn': [runtimeconfigName]
        }
    }
    return variable