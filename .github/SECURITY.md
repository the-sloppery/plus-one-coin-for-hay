# Security

Do not open a public issue for a vulnerability or secret exposure. Follow the
private security reporting path configured by the repository owner and include
only the minimum safe reproduction.

Never commit credentials. Development and test secrets use the approved secret
provider; production secrets use the approved production vault. The canonical
organization boundary is recorded in
[`sloppery-dev/context/repository-boundaries.json`](https://github.com/the-sloppery/sloppery-dev/blob/main/context/repository-boundaries.json).
