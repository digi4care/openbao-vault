# Token Rotation in OpenBAO

This document explains how token rotation works in OpenBAO and how you can use the `rotate_tokens.sh` script to improve your security posture.

## What is token rotation?

In OpenBAO/Vault, tokens are used to access secrets and resources. A token is a type of temporary password that provides access to specific resources based on the associated policies.

The problem with permanent tokens or tokens with a very long lifetime is that they pose a significant security risk if they are stolen, leaked, or compromised. If an attacker gains access to a permanent token, they potentially have unlimited access to sensitive data.

Token rotation is a security practice where tokens are regularly replaced with new tokens that have a limited lifetime. This limits the damage that can be done if a token is compromised.

## How does the `rotate_tokens.sh` script work?

The `rotate_tokens.sh` script automates the process of token rotation and implements best practices for token lifecycle management. The script does the following:

1. **Creates short-term tokens**: Instead of using a token that is valid forever, this script creates tokens that automatically expire after a certain time (TTL - Time To Live).

2. **Sets a maximum lifetime**: Even if you renew the token, it will eventually expire permanently after the maximum lifetime (max TTL).

3. **Associates tokens with specific policies**: The token only gets the permissions it needs, following the principle of least privilege.

4. **Stores tokens securely**: The script saves the new tokens in files that you can use in your applications or scripts.

5. **Supports different authentication methods**: The script works with both userpass authentication (for human users) and AppRole authentication (for services and applications).

## Practical examples

### For human users (userpass authentication)

Suppose you have a global admin account and you want to work securely:

```bash
./run_in_container.sh rotate_tokens.sh -u admin.user -t 1h -m 24h -p admin
```

This gives you a token that:

- Is valid for 1 hour (`-t 1h`)
- Can be renewed for a maximum of 24 hours (`-m 24h`)
- Has the admin policy (`-p admin`)

You use this token for your work instead of entering your password each time. After 1 hour, the token must be renewed, which can happen automatically if your application supports it. After 24 hours, the token expires permanently and you need to create a new token.

### For services (AppRole authentication)

For automated processes and applications:

```bash
./run_in_container.sh rotate_tokens.sh -r payment-service -t 1h -p payment-service-policy
```

This creates a token for the payment-service AppRole with the same lifetime restrictions.

## Why is token rotation important?

1. **Limited damage in case of theft**: If someone steals your token, they have access for a maximum of the TTL or max TTL, not forever.

2. **Automatic revocation**: You don't need to manually revoke tokens; they expire automatically after the set period.

3. **Audit trail**: Each token leaves traces in the audit logs, so you can see who did what and when.

4. **No password storage**: Applications don't need to store passwords, only short-term tokens that are regularly refreshed.

5. **Compliance**: Many security standards and compliance frameworks (such as PCI DSS, SOC2, ISO 27001) require regular rotation of credentials.

## Best practices for token rotation

1. **Use short TTLs**: The shorter the lifetime of a token, the more secure it is. For interactive sessions, 1-4 hours is usually sufficient.

2. **Implement automatic renewal**: For longer sessions, implement automatic token renewal in your applications.

3. **Limit the maximum lifetime**: Even with renewal, a token must eventually expire. A max TTL of 24-72 hours is common.

4. **Use different tokens for different purposes**: Create separate tokens for different applications or functions, each with their own specific policies.

5. **Store tokens securely**: Treat tokens as sensitive data and store them securely, for example in a secrets manager or as environment variables.

6. **Rotate regularly**: Implement a schedule for regular token rotation, even before tokens expire.

## Integration with CI/CD and automation

For production environments, it is recommended to integrate token rotation into your CI/CD pipeline or automation processes:

1. **Scheduled jobs**: Use cron jobs or scheduled tasks to regularly generate new tokens.

2. **Secrets management**: Integrate with a secrets manager such as HashiCorp Vault itself, AWS Secrets Manager, or Azure Key Vault to securely store and distribute tokens.

3. **Monitoring**: Implement monitoring to alert when tokens are about to expire or when there is unusual token activity.

## Conclusion

Token rotation is an essential security practice for any OpenBAO/Vault implementation. By regularly refreshing tokens and limiting their lifetime, you significantly reduce the risk of unauthorized access to your secrets and systems.

The `rotate_tokens.sh` script makes it easy to implement this best practice in your environment, whether you're a single admin or a large team with many services and applications.
