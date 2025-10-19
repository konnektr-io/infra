# PostgreSQL Database for KtrlPlane

This directory contains the Kubernetes manifests for deploying a PostgreSQL database for your development application.

## Files

- `ktrlplane-db-namespace.yaml` - Creates the ktrlplane namespace
- `ktrlplane-db-secret.yaml` - Contains database credentials (base64 encoded)
- `ktrlplane-db-pvc.yaml` - Persistent Volume Claim for database storage (20Gi)
- `ktrlplane-db-deployment.yaml` - PostgreSQL deployment with PostgreSQL 15 Alpine
- `ktrlplane-db-service.yaml` - ClusterIP service for internal cluster access

## Default Credentials

- **Username**: `postgres`
- **Password**: `password`
- **Database**: `ktrlplane`

⚠️ **Security Note**: Change the default password in `ktrlplane-db-secret.yaml` before deploying to production!

## Deployment

Apply the manifests in the following order:

```bash
kubectl apply -f ktrlplane-db-namespace.yaml
kubectl apply -f ktrlplane-db-secret.yaml
kubectl apply -f ktrlplane-db-pvc.yaml
kubectl apply -f ktrlplane-db-deployment.yaml
kubectl apply -f ktrlplane-db-service.yaml
```

Or apply all at once:

```bash
kubectl apply -f ktrlplane/
```

## Connection

### From within the cluster:

- **Host**: `ktrlplane-db.ktrlplane.svc.cluster.local`
- **Port**: `5432`

### From outside the cluster (via nginx TCP forwarding):

- **Host**: `<your-cluster-ip-or-domain>`
- **Port**: `5432`

The nginx ingress has been configured with TCP forwarding on port 5432 to allow direct external connections to the PostgreSQL database.

## Resources

- **CPU**: 250m (request), 500m (limit)
- **Memory**: 256Mi (request), 512Mi (limit)
- **Storage**: 20Gi persistent volume

## Health Checks

The deployment includes:

- **Liveness Probe**: Checks if PostgreSQL is responsive every 10 seconds
- **Readiness Probe**: Checks if PostgreSQL is ready to accept connections every 5 seconds
