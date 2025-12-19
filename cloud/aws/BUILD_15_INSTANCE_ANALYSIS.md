# Build 15 Instance Analysis

## Question
Why does `nomad node status` show 2 clients but `aws ec2 describe-instances` only shows 1 client instance?

## EC2 Instances (filtered by Name=*scale*)
```
mws-scale-ubuntu-client-windows  35.89.114.38   172.31.39.51   i-0f2e74fcb95361c77  t3a.xlarge
mws-scale-ubuntu-server-1        44.248.178.38  172.31.51.88   i-0666ca6fd4c5fe276  t3a.medium
```

## Nomad Nodes
```
ID        Node Pool  DC   Name              Class               Drain  Eligibility  Status
10b6ec7f  default    dc1  ip-172-31-40-228  hashistack-linux    false  eligible     ready
3621a197  default    dc1  EC2AMAZ-3ESQ0TF   hashistack-windows  false  eligible     ready
```

## Analysis

### Instance Mapping
1. **Server**: i-0666ca6fd4c5fe276 → NOT a Nomad client (it's the server)
2. **Windows Client**: i-0f2e74fcb95361c77 → Nomad node 3621a197 (EC2AMAZ-3ESQ0TF)
3. **Linux Client**: ??? → Nomad node 10b6ec7f (ip-172-31-40-228)

### The Missing Instance

The Linux client node `ip-172-31-40-228` (private IP 172.31.40.228) is NOT in the filtered EC2 list.

**Possible Reasons:**
1. The instance name doesn't match the filter `*scale*`
2. The instance was launched by ASG with a different naming pattern
3. The instance is in a different state or region

### Verification Needed

Check ALL instances without name filter:
```bash
aws ec2 describe-instances --region us-west-2 \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

Look for instance with private IP: 172.31.40.228

### Expected Finding

The Linux client instance likely has a name like:
- `mws-scale-ubuntu-client-linux-<random>` (ASG generated name)
- Or no Name tag at all
- Or a name that doesn't contain "scale"

## Conclusion

**There ARE 2 client instances running:**
1. Linux client (from ASG scale-up) - Private IP: 172.31.40.228
2. Windows client (from original deployment) - Private IP: 172.31.39.51

The EC2 describe command filter `Name=tag:Name,Values=*scale*` is too restrictive and misses the Linux client instance.

## Action Required

Run unfiltered EC2 query to find the Linux client instance ID.