import re
import random
import string

def _SanitizeDeploymentName(deploymentName):
    sanitizedName = '-'.join(deploymentName.split("-")[-2:])[-20:]
    if re.match('[0-9-].*', sanitizedName):
        sanitizedName = 'cb-' + sanitizedName[-17:]
    random.seed(hash(sanitizedName))
    randomString = ''.join(random.choice(string.ascii_lowercase) for i in range(10))
    sanitizedName += '-' + randomString
    return sanitizedName

def BaseDeploymentName(context):
    return _SanitizeDeploymentName(context.env['deployment'])

def ClusterName(context, clusterName):
    return '%s-%s' % (BaseDeploymentName(context), clusterName)

def GroupName(context, clusterName, groupName):
    return '%s-%s-%s' % (BaseDeploymentName(context), clusterName, groupName)

def RuntimeConfigName(context):
    return '%s-runtimeconfig' % BaseDeploymentName(context)

def WaiterName(context, clusterName, groupName):
    return '%s-%s-%s-waiter' % \
           (BaseDeploymentName(context), clusterName, groupName)

def ExternalIpVariableCreateActionName(context, clusterName, groupName):
    return '%s-%s-%s-ext-ip-create' % \
           (BaseDeploymentName(context), clusterName, groupName)

def ExternalIpVariableReadActionName(context, clusterName, groupName):
    return '%s-%s-%s-ext-ip-read' % \
           (BaseDeploymentName(context), clusterName, groupName)

def ExternalIpOutputName(context, clusterName, groupName):
    return '%s-externalIp-%s-%s' % (BaseDeploymentName(context), clusterName, groupName)

def FirewallName(context):
    return '%s-firewall' % BaseDeploymentName(context)

def InstanceTemplateName(context, clusterName, groupName):
    return '%s-%s-%s-it' % \
           (BaseDeploymentName(context), clusterName, groupName)

def InstanceGroupManagerName(context, clusterName, groupName):
    return '%s-%s-%s-igm' % \
           (BaseDeploymentName(context), clusterName, groupName)

def InstanceGroupInstanceBaseName(context, clusterName, groupName):
    return '%s-%s-%s-vm' % \
           (BaseDeploymentName(context), clusterName, groupName)

def UsernameVariableName(context):
    return '%s-cb-username' % (BaseDeploymentName(context))

def PasswordVariableName(context):
    return '%s-cb-password' % (BaseDeploymentName(context))
