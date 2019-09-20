#!/usr/bin/env python

import argparse
import hashlib

#
# Parse password argument
#
parser = argparse.ArgumentParser(description='Generate an SHA512 password hash for the given password')
parser.add_argument(
    'password',
    metavar='PASSWORD',
    type=str,
    nargs=1,
    help='A password to generate a SHA512 hash of'
)
args = parser.parse_args()

#
# Validate password is non-null and 6+ chars
#
try:
    assert(args.password is not None)
    assert(isinstance(args.password, list))
    assert(len(args.password) > 0)
    assert(len(args.password[0]) >= 6)

    password = args.password[0]
except AssertionError:
    print('Must supply a password of at least six characters!')
    exit(1)

#
# Generate an SHA512 hash, write it to a file and print it in a message
#
with open('dcos_superuser_password_hash', 'w') as f:
    m = hashlib.sha512(password.encode())
    digest = m.hexdigest()

    f.write(digest)
    print(f"Wrote SHA512 digest: '{digest}' for password '{password}' to ./dcos_superuser_password_hash")

