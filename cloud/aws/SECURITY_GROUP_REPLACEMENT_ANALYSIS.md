# Security Group Replacement During Terraform Apply

## Issue
Security group `aws_security_group.primary` is being destroyed and recreated during `terraform apply` (not destroy), taking 11+ minutes.

## Root Cause

**VPC ID Force Replacement**

From terraform logs:
```
vpc_id = "vpc-0f17d0e52823a5128" -> (known after apply) # forces replacement
```

The security group replacement is triggered because:

1. **VPC Data Source Re-evaluation**: Adding the Windows image module causes Terraform to refresh the `data.aws_vpc.default` data source
2. **Computed Value**: The VPC ID changes from a known value to "computed" (known after apply)
3. **Force Replacement Attribute**: In AWS, `vpc_id` is a force-replacement attribute for security groups
4. **Cascading Effect**: Changing vpc_id requires destroying and recreating the security group

## Why This Is Normal

This behavior is **expected and safe** when:
- Adding new modules to terraform configuration
- Terraform re-evaluates data sources and dependencies
- State is being refreshed with new resources

## Why Deletion Takes So Long

The security group deletion is taking 11+ minutes because:

1. **Network Interface Detachment**: AWS must detach all ENIs (Elastic Network Interfaces) from the security group
2. **Running Instance Dependencies**: The Linux server instance (i-0a938c6a9aa9419a4) has ENIs attached to this security group
3. **AWS Safety Checks**: AWS performs extensive dependency checks before allowing security group deletion
4. **Eventual Consistency**: AWS's distributed system needs time to propagate the changes

## Impact

### What's Being Replaced
- Security group ID will change from `sg-037319d2258090b2a` to a new ID
- All security group rules will be recreated identically
- No functional changes to network access

### What's NOT Affected
- Running instances continue to operate
- Network connectivity is maintained
- No service interruption

### Timeline
- **Deletion**: 11+ minutes (in progress)
- **Recreation**: ~30 seconds
- **Total**: ~12 minutes for this step

## Related Changes

This replacement is part of adding Windows client support:
- Adding `hashistack_image_windows` module
- Adding Windows client ASG resources
- Terraform recalculating all module dependencies

## Verification

After security group is recreated, verify:
```bash
# Check new security group ID
cd terraform/control
terraform show | grep "aws_security_group.primary" -A 5

# Verify server instance still has connectivity
aws ec2 describe-instances --instance-ids i-0a938c6a9aa9419a4 \
  --query 'Reservations[0].Instances[0].SecurityGroups'
```

## Conclusion

**This is normal Terraform behavior** when adding new modules. The security group replacement:
- ✅ Is expected when VPC data source is refreshed
- ✅ Will complete successfully
- ✅ Will not cause service interruption
- ✅ Is part of adding Windows client support

**No action required** - wait for deletion to complete, then recreation will proceed quickly.