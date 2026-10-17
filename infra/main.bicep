// logistics-intake: the logistics domain's intake flow (ADR 0015), a Logic App (Consumption) in
// rg-intplat-logistics-intake. The platform's event intake delivers OrderReadyForShipment to it (ADR 0016); it books the order's shipment with the 3PL partner (partner API 2.3),
// through the gateway, as its runtime identity. Pay per run: nothing polls.

param location string = 'belgiumcentral'

@description('Application (client) id of the intplat-platform-apis Entra application (ADR 0014).')
param platformApisAppId string = 'e3337087-144a-4b2e-8faa-c802660b9dee'

var tags = {
  project: 'ai-intelligence-domain'
  component: 'logistics-intake'
  owner: 'logistics-team'
}

resource runtime 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: 'id-intplat-logistics-intake-runtime'
  scope: resourceGroup('rg-intplat-identities')
}

resource gateway 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: 'apim-intplat-demo'
  scope: resourceGroup('rg-intplat-platform')
}

// The flow's definition is workflow.json; its calls run as the runtime identity, for the
// platform's internal audience (the gateway's system-apis product).
var definition = json(replace(replace(loadTextContent('../workflow.json'),
  '__IDENTITY__', runtime.id),
  '__AUDIENCE__', 'api://${platformApisAppId}'))

resource flow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'la-intplat-logistics-intake'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${runtime.id}': {} }
  }
  properties: {
    state: 'Enabled'
    definition: definition
    parameters: {
      gateway: { value: gateway.properties.gatewayUrl }
    }
    // Only the gateway may start a run: an Entra token of its managed identity, for the platform's
    // internal audience. No shared access signature leaves Azure.
    accessControl: {
      triggers: {
        openAuthenticationPolicies: {
          policies: {
            gateway: {
              type: 'AAD'
              claims: [
                { name: 'iss', value: 'https://sts.windows.net/${tenant().tenantId}/' }
                { name: 'aud', value: 'api://${platformApisAppId}' }
                { name: 'oid', value: gateway.identity.principalId }
              ]
            }
          }
        }
      }
    }
  }
}

output name string = flow.name
output invokeUrl string = '${flow.properties.accessEndpoint}/triggers/event/paths/invoke?api-version=2016-10-01'
