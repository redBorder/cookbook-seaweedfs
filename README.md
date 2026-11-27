# cookbook-seaweedfs
[![Build Status][build-shield]][build-url]
[![Linters][linters-shield]][linters-url]
[![License][license-shield]][license-url]

<!-- Badges -->
[build-shield]: https://github.com/redBorder/cookbook-seaweedfs/actions/workflows/rpm.yml/badge.svg?branch=master
[build-url]: https://github.com/redBorder/cookbook-seaweedfs/actions/workflows/rpm.yml?query=branch%3Amaster
[linters-shield]: https://github.com/redBorder/cookbook-seaweedfs/actions/workflows/lint.yml/badge.svg?event=push
[linters-url]: https://github.com/redBorder/cookbook-seaweedfs/actions/workflows/lint.yml
[license-shield]: https://img.shields.io/badge/license-AGPLv3-blue.svg
[license-url]: https://github.com/redBorder/cookbook-seaweedfs/blob/HEAD/LICENSE

Cinc cookbook to install and configure SeaweedFS (package `redborder-seaweedfs`), the S3 object
storage of redborder. It replaces cookbook-minio.

## Cluster

All the managers with the `s3` service form one SeaweedFS cluster:

| Service | Where | Port (HTTP / gRPC) |
| --- | --- | --- |
| `seaweedfs-master` | First manager with 1–2 S3 managers, first 3 with 3 or more (Raft) | 9333 / 19333 |
| `seaweedfs-volume` | Every S3 manager | 9340 / 19340 |
| `seaweedfs-filer` (+ S3 gateway) | Every S3 manager | 9350 / 19350, S3 8333 |

- Each filer keeps the metadata in a local leveldb2 store and the filers replicate the changes
  between them, so the S3 service does not depend on PostgreSQL (it is configured before it).
- Replication `000` with one S3 manager and `001` (one more copy in another manager) with more.
  The cookbook changes the existing volumes when the number of S3 managers changes.
- S3 identities in `/etc/seaweedfs/s3.json`: the admin user, and the malware user limited to
  the `malware` bucket.
- Telemetry and the unused S3 listeners (IAM API, Iceberg, Lance) are disabled. master, volume
  and filer listen on the sync address; the S3 gateway in every interface (nginx uses
  localhost during the install), opened only in the home zone of the firewall.
- `security.toml`: JWT keys (derived from the S3 secret of the cluster) for the volume and filer
  APIs, and the HTTP write API of master and volume only from the S3 managers (`-whiteList`).

### Platforms

- Rocky Linux 9

### Cinc

- Cinc Client 19 or later

## License

GNU AFFERO GENERAL PUBLIC LICENSE Version 3, 19 November 2007
