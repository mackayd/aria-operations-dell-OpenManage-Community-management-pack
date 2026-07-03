# Dell OME RestAPI Community Management Pack

Community VMware Aria Operations management pack for monitoring Dell OpenManage Enterprise 4.x using the Dell OpenManage Enterprise REST API.

This management pack is built with **Aria Management Pack Builder** and collects server inventory, health, power, temperature, operating system, location, and hardware component information from Dell OpenManage Enterprise.

It uses Dell OME REST endpoints under `/api` only. It does **not** use Redfish and does **not** require an external shim, proxy, or normalising service.

## Release

| Item | Value |
| --- | --- |
| Management Pack | Dell OME RestAPI Community Management Pack |
| Version | 1.5.0 |
| Author | Drew Mackay |
| Description | Aria Operations Community management pack for Dell OpenManage Enterprise 4.x |
| Source type | Aria Management Pack Builder HTTP adapter |
| API used | Dell OpenManage Enterprise REST `/api` |
| Redfish used | No |
| External shim/proxy required | No |
| Licence | MIT |

## Repository Contents

```text
.
├── LICENSE.md
├── README.md
├── PAK Installers
│   ├── Dell-OME-RestAPI-Community-Management-Pack-1.5.0.pak
│   └── Dell-OME-RestAPI-Community-Management-Pack-1.5.0-icons.pak
├── mp-builder
│   └── Dell-OME-RestAPI-Community-Management-Pack-Export-1.5.0.json
└── CustomIcon-tooling
    ├── inject-ome-pak-assets.ps1
    └── icons
        ├── dell-ome-appliance.png
        ├── dell-server.png
        ├── dell-cpu-socket.png
        ├── dell-memory-dimm.png
        ├── dell-storage-controller.png
        ├── dell-storage-drive.png
        ├── dell-power-supply.png
        ├── dell-server-subsystem-health.png
        └── production-icons-contact-sheet.png
```

## Which PAK Should I Install?

Two PAK files are included:

| PAK | Use case |
| --- | --- |
| `Dell-OME-RestAPI-Community-Management-Pack-1.5.0.pak` | Standard MP Builder-generated PAK. Use this if you want the clean baseline output exactly as produced by MP Builder. |
| `Dell-OME-RestAPI-Community-Management-Pack-1.5.0-icons.pak` | Same management pack with custom resource icons injected after the PAK was built. This is the recommended PAK for normal use. |

The icon-injected PAK does not change collection logic, API requests, metrics, relationships, dashboards, or adapter behaviour. It only updates image assets so Dell OME resource types are easier to recognise in Aria Operations.

## What It Monitors

The management pack discovers Dell servers managed by Dell OpenManage Enterprise and collects the following data where available from Dell OME.

### Dell OME Appliance

- Appliance display name
- GUID
- OME version
- Build number

### Dell Server

- Display name
- OME device ID
- Service tag
- Identifier
- Model
- Asset tag
- System ID
- Health/status
- Power state
- Managed state
- Connection state
- Current, average, and peak power
- Instantaneous power headroom
- Current, average, and peak temperature
- Operating system name
- Operating system version
- Operating system hostname
- Data center
- Room
- Aisle
- Rack
- Rack slot
- Management IP address
- Management MAC address
- Management DNS name
- System uptime seconds

### Hardware Components

The pack creates direct Dell Server child objects for:

- Dell CPU Socket
- Dell Memory DIMM
- Dell Storage Controller
- Dell Storage Drive
- Dell Power Supply
- Dell Server Subsystem Health

The direct child topology is intentional and validated. Deeper subsystem-container topology, for example `Memory -> DIMM` or `Storage -> Drive`, is not implemented in this release.

## Topology Model

```text
Dell OME Appliance
└── Dell Server
    ├── Dell CPU Socket
    ├── Dell Memory DIMM
    ├── Dell Storage Controller
    ├── Dell Storage Drive
    ├── Dell Power Supply
    └── Dell Server Subsystem Health
```

## Dell OME REST API Endpoints Used

The pack uses Dell OpenManage Enterprise REST endpoints under `/api`, including:

```text
api/SessionService/Sessions
api/ApplicationService/Info
api/DeviceService/Devices
api/DeviceService/Devices(${requestParameters.id})/Power
api/DeviceService/Devices(${requestParameters.id})/Temperature
api/DeviceService/Devices(${requestParameters.id})/InventoryDetails('serverProcessors')
api/DeviceService/Devices(${requestParameters.id})/InventoryDetails('serverMemoryDevices')
api/DeviceService/Devices(${requestParameters.id})/InventoryDetails('serverRaidControllers')
api/DeviceService/Devices(${requestParameters.id})/InventoryDetails('serverArrayDisks')
api/DeviceService/Devices(${requestParameters.id})/InventoryDetails('serverPowerSupplies')
api/DeviceService/Devices(${requestParameters.id})/InventoryDetails('serverOperatingSystems')
api/DeviceService/Devices(${requestParameters.id})/InventoryDetails('deviceLocation')
api/DeviceService/Devices(${requestParameters.id})/InventoryDetails('deviceManagement')
api/DeviceService/Devices(${requestParameters.id})/SystemUpTime
api/DeviceService/Devices(${requestParameters.id})/SubSystemHealth
```

## Requirements

### Aria Operations

- VMware Aria Operations with Management Pack installation rights.
- A collector or cloud proxy that can reach Dell OpenManage Enterprise over HTTPS.
- Permission to add integrations/adapters and credentials.

### Dell OpenManage Enterprise

- Dell OpenManage Enterprise 4.x.
- A Dell OME user account that can read device inventory, power, temperature, subsystem health, and inventory details.
- HTTPS access from the Aria Operations collector/cloud proxy to Dell OME.

### Network

Default traffic flow:

```text
Aria Operations Collector / Cloud Proxy -> Dell OpenManage Enterprise HTTPS / TCP 443
```

No inbound connection from Dell OME to Aria Operations is required for normal polling.

## Installing the PAK in Aria Operations

1. Log in to Aria Operations with an account that can install management packs.
2. Go to **Administration** > **Integrations** > **Repository**.
3. Click **Add** or **Upload**.
4. Select the recommended PAK:

   ```text
   PAK Installers/Dell-OME-RestAPI-Community-Management-Pack-1.5.0-icons.pak
   ```

5. Accept the prompts and allow the PAK to install.
6. Wait for the installation to complete successfully.
7. Go to **Administration** > **Integrations**.
8. Find **Dell OME RestAPI Community Management Pack**.
9. Click **Add Account**.
10. Enter the Dell OME connection details.

### Adapter Instance Settings

| Setting | Description | Example |
| --- | --- | --- |
| Dell OME Hostname | Dell OpenManage Enterprise FQDN or IP | `<DELL_OME_FQDN>` |
| Dell OME Port | HTTPS port | `443` |
| SSL | Certificate validation mode | `NO_VERIFY` for lab/self-signed certs, `VERIFY` for trusted certs |
| Connection Timeout | HTTP timeout in seconds | `30` |
| Max Concurrent Requests | Maximum concurrent REST calls | `4` |
| Maximum Retries | Retry count | `2` |
| Minimum VMware Aria Operations Severity | Minimum event severity setting | `WARNING` |

### Credentials

Create or select credentials for Dell OpenManage Enterprise:

| Field | Description |
| --- | --- |
| Dell OME Username | Dell OME REST API username |
| Dell OME Password | Dell OME REST API password |

The password is stored by Aria Operations as a credential secret. Do not store Dell OME credentials in the repository.

### Test Connection and First Collection

After adding the adapter instance:

1. Click **Test Connection**.
2. Confirm the test passes.
3. Save the adapter instance.
4. Allow at least one full collection cycle to complete.
5. Confirm Dell Server and child component objects appear in Inventory.

The first collection can take several minutes, especially while Aria Operations updates the object inventory and topology view.

## Dashboard

The PAK includes a dashboard named:

```text
Dell OME RestAPI Community Management Pack/Dell OME Server Health Status
```

The dashboard is intended to provide a quick operational view of Dell server health and component inventory.

Expected dashboard content includes:

- All Dell Servers
- Selected server summary
- Power and temperature data
- CPU sockets
- Memory DIMMs
- Storage controllers
- Storage drives
- Power supplies
- Subsystem health

Dashboard receiver-widget behaviour can vary depending on Aria Operations version and widget configuration. The validated operator path for detailed parent-child topology is the Aria Operations Inventory topology view.

## Importing the MP Builder JSON for Editing

The MP Builder export is included for users who want to inspect, modify, or rebuild the management pack.

File:

```text
mp-builder/Dell-OME-RestAPI-Community-Management-Pack-Export-1.5.0.json
```

### Import Steps

1. Log in to Aria Management Pack Builder.
2. Choose the option to import an existing management pack design.
3. Select:

   ```text
   mp-builder/Dell-OME-RestAPI-Community-Management-Pack-Export-1.5.0.json
   ```

4. Import the design.
5. Review the source configuration.
6. Update Dell OME hostname defaults if required.
7. Review the Dell OME REST session authentication settings.
8. Run source tests from MP Builder.
9. Make any required changes.
10. Build a new PAK from MP Builder.

### Important Notes When Editing

- Keep the Dell OME REST `/api` approach intact.
- Do not add Redfish requests unless you intentionally want a different pack design.
- Do not add an external shim/proxy requirement.
- Preserve request chaining from `api/DeviceService/Devices` into per-server inventory endpoints.
- Preserve the parent/child relationships unless you are deliberately changing topology.
- If you change object type names, update the icon mapping and icon injection process.

## Running the Custom Icon Injector

The repository includes the icon injector used to create the icon-enhanced PAK.

Script:

```text
CustomIcon-tooling/inject-ome-pak-assets.ps1
```

Icons:

```text
CustomIcon-tooling/icons
```

### Icon Requirements

The injector expects PNG files for each mapped resource type. The included icons are 400x400 PNG files.

Expected icon filenames:

```text
dell-ome-appliance.png
dell-server.png
dell-cpu-socket.png
dell-memory-dimm.png
dell-storage-controller.png
dell-storage-drive.png
dell-power-supply.png
dell-server-subsystem-health.png
```

### Basic Usage

From the root of the repository:

```powershell
.\CustomIcon-tooling\inject-ome-pak-assets.ps1 `
  -Pak ".\PAK Installers\Dell-OME-RestAPI-Community-Management-Pack-1.5.0.pak" `
  -IconsDir ".\CustomIcon-tooling\icons" `
  -Output ".\PAK Installers\Dell-OME-RestAPI-Community-Management-Pack-1.5.0-icons.pak" `
  -Force
```

### Allowing Non-400x400 Icons

The validated release icon standard is 400x400 PNG. If you are testing different icon sizes, you can use:

```powershell
.\CustomIcon-tooling\inject-ome-pak-assets.ps1 `
  -Pak ".\PAK Installers\Dell-OME-RestAPI-Community-Management-Pack-1.5.0.pak" `
  -IconsDir ".\CustomIcon-tooling\icons" `
  -Output ".\PAK Installers\Dell-OME-RestAPI-Community-Management-Pack-1.5.0-icons.pak" `
  -AllowNon400 `
  -Force
```

### What the Injector Changes

The injector patches image assets in the PAK and nested adapter archive. It does not intentionally modify:

- API requests
- adapter credentials
- dashboards
- object model
- relationships
- metrics or properties

After running the injector, install the generated icon PAK into a test Aria Operations environment and confirm the icons display as expected.

## Known Limitations

- Hardware logs are not included in version 1.5.0.
- Recent activity is not included in version 1.5.0.
- OME alerts are not included in version 1.5.0.
- Deeper subsystem-container topology is not implemented in this release. Components are direct children of the Dell Server object.
- Dashboard receiver-widget behaviour may need tuning for richer cross-widget interaction.
- Component availability depends on what Dell OpenManage Enterprise exposes for each managed device.
- Fan and temperature sensor child objects are not modelled as individual Aria child objects in this release. Server-level temperature and subsystem health are included.

## Validation Checklist

After installing the PAK and creating an adapter instance, confirm:

- Test Connection passes.
- Collection completes successfully.
- Dell OME Appliance object appears.
- Dell Server objects appear with readable names.
- CPU Socket objects appear under Dell Server.
- Memory DIMM objects appear under Dell Server.
- Storage Controller objects appear under Dell Server.
- Storage Drive objects appear under Dell Server.
- Power Supply objects appear under Dell Server.
- Server Subsystem Health objects appear under Dell Server.
- Server OS information appears on Dell Server.
- Server location information appears on Dell Server.
- Dashboard opens and populates.
- Custom icons appear when using the icon-injected PAK.

## Troubleshooting

### Test Connection Fails

Check:

- Dell OME hostname and port.
- Dell OME credentials.
- Collector/cloud proxy network route to Dell OME.
- TLS certificate setting: use `NO_VERIFY` for lab/self-signed certificates or `VERIFY` for trusted certificates.
- Dell OME REST API availability.

### No Servers Discovered

Check:

- The Dell OME account can see managed devices.
- Dell servers are discovered and inventoried in Dell OME.
- The `api/DeviceService/Devices` endpoint returns managed devices.
- Aria collection has completed after saving the adapter instance.

### Child Components Missing

Check:

- The server has recent inventory in Dell OME.
- Dell OME returns data for the relevant inventory type.
- The collection cycle has completed and the inventory view has refreshed.
- The child object type is included in this release.

### Dashboard Is Empty

Check:

- Collection has completed.
- Dell Server objects exist.
- The dashboard was imported with the PAK.
- The selected object/resource kind matches the widget configuration.

## Security Notes

- Do not commit real Dell OME credentials.
- Do not commit session tokens, cookies, or generated debug logs containing secrets.
- The MP Builder JSON should contain credential field definitions and placeholders only.
- Review any exported MP Builder JSON before publishing modifications.
- Use a least-privilege Dell OME account with read-only access where possible.

## Development Notes

The management pack is built with Aria Management Pack Builder. The included JSON export is the editable source for the pack. The PAK files are the installable outputs.

Recommended development workflow:

```text
1. Import MP Builder JSON.
2. Modify the MPB design.
3. Build a standard PAK.
4. Test the standard PAK.
5. Inject icons if required.
6. Test the icon-injected PAK.
7. Update README/release notes.
```

## Disclaimer

This is a community management pack. It is not an official Dell, VMware, or Broadcom product. Validate in a non-production Aria Operations environment before using it in production.

## Licence

This project is released under the MIT licence. See `LICENSE.md`.
