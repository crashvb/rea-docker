FROM node:22.22.0-bookworm-slim@sha256:dd9d21971ec4395903fa6143c2b9267d048ae01ca6d3ea96f16cb30df6187d94 AS node

FROM crashvb/supervisord:202610210041@sha256:689d6c587164f57d8ea8888265850c3d6c65e020d345a82f772eacfed9ec0f82 AS builder
ARG GHIDRA_RELEASE=20260921
ARG GHIDRA_SHA256=ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db
ARG GHIDRA_VERSION=12.1.4
ARG HOPPER_LAUNCHER_SHA256=b2271008fb82bf14cfae5c3644cdde2b11fc6804bd7c99d67032ec1b1942d53c
ARG HOPPER_PACKAGE_SHA256=59705e50f7ebf9104abe1e72ac3949bed1a8e43ec67a8c9510a1c5056c200d27
ARG HOPPER_VERSION=6.6.0
ARG KUNA_SHA256_AMD64=e9f047fb5a93925ede6d869df22c26c1c0ced90764ace7467ae90f880625d530
ARG KUNA_SHA256_ARM64=c1f7cd7cdb990cdf1149d2f595a56adf3a4afce052d014b2b6670adbfbcc71e5
ARG KUNA_VERSION=1.833
ARG NPM_VERSION=11.16.0
ARG REA_REVISION=52c84f6f58fa3cc7b39326654c6d3f261f957957
ARG REA_SOURCE_SHA256=899e98f67337589e96de4a115447de5dd0792123a27a07375143ca5e51b565aa
ARG TARGETARCH
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install packages, download files ...
RUN docker-apt unzip
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/ /usr/local/lib/node_modules/
RUN ln --symbolic ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
	ln --symbolic ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx && \
	npm install --global "npm@${NPM_VERSION}"

# Build: ghidra
RUN curl --fail --location --output /tmp/ghidra.zip --silent --show-error \
		"https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${GHIDRA_VERSION}_build/ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_RELEASE}.zip" && \
	echo "${GHIDRA_SHA256}  /tmp/ghidra.zip" | sha256sum --check --strict && \
	unzip -q /tmp/ghidra.zip -d /opt && \
	mv "/opt/ghidra_${GHIDRA_VERSION}_PUBLIC" /opt/ghidra && \
	rm --force /tmp/ghidra.zip

# Build: hopper
RUN test "${TARGETARCH}" = amd64 && \
	curl --fail --location --output /tmp/hopper.deb --silent --show-error --user-agent rea-installer \
		"https://www.hopperapp.com/downloader/public/Hopper-${HOPPER_VERSION}-Linux-demo.deb" && \
	echo "${HOPPER_PACKAGE_SHA256}  /tmp/hopper.deb" | sha256sum --check --strict

# Build: kuna
RUN case "${TARGETARCH}" in \
		amd64) kuna_arch=x86_64; kuna_sha256="${KUNA_SHA256_AMD64}" ;; \
		arm64) kuna_arch=arm64; kuna_sha256="${KUNA_SHA256_ARM64}" ;; \
		*) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
	esac && \
	curl --fail --location --output /tmp/kuna.tar.gz --silent --show-error \
		"https://github.com/Noelo-Lab/kuna/releases/download/v${KUNA_VERSION}/kuna-v${KUNA_VERSION}-linux-${kuna_arch}.tar.gz" && \
	echo "${kuna_sha256}  /tmp/kuna.tar.gz" | sha256sum --check --strict && \
	tar --directory=/tmp --extract --file=/tmp/kuna.tar.gz --gzip && \
	install --mode=0755 "/tmp/kuna-v${KUNA_VERSION}-linux-${kuna_arch}/kuna" /usr/local/bin/kuna && \
	kuna --version

# Build: rea
WORKDIR /usr/src/rea
RUN curl --fail --location --output /tmp/rea.tar.gz --silent --show-error "https://github.com/morluto/rea/archive/${REA_REVISION}.tar.gz" && \
	echo "${REA_SOURCE_SHA256}  /tmp/rea.tar.gz" | sha256sum --check --strict && \
	tar --directory=/usr/src/rea --extract --file=/tmp/rea.tar.gz --strip-components=1 && \
	HUSKY=0 npm ci --audit=false --fund=false && \
	npm pack --pack-destination=/tmp && \
	npm install --global /tmp/rea-agents-*.tgz && \
	rea mcp --http --help > /dev/null && \
	npm cache clean --force

FROM crashvb/supervisord:202610210041@sha256:689d6c587164f57d8ea8888265850c3d6c65e020d345a82f772eacfed9ec0f82
ARG GHIDRA_VERSION=12.1.4
ARG HOPPER_LAUNCHER_SHA256=b2271008fb82bf14cfae5c3644cdde2b11fc6804bd7c99d67032ec1b1942d53c
ARG HOPPER_VERSION=6.6.0
ARG KUNA_VERSION=1.833
ARG REA_REVISION=52c84f6f58fa3cc7b39326654c6d3f261f957957
ARG REA_VERSION=6.7.0
ARG org_opencontainers_image_created=undefined
ARG org_opencontainers_image_revision=undefined
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
LABEL \
	org.opencontainers.image.authors="Richard Davis <crashvb@gmail.com>" \
	org.opencontainers.image.base.digest="sha256:689d6c587164f57d8ea8888265850c3d6c65e020d345a82f772eacfed9ec0f82" \
	org.opencontainers.image.base.name="crashvb/supervisord:202610210041" \
	org.opencontainers.image.created="${org_opencontainers_image_created}" \
	org.opencontainers.image.description="Image containing REA." \
	org.opencontainers.image.licenses="Apache-2.0" \
	org.opencontainers.image.source="https://github.com/crashvb/rea-docker" \
	org.opencontainers.image.revision="${org_opencontainers_image_revision}" \
	org.opencontainers.image.title="crashvb/rea" \
	org.opencontainers.image.url="https://github.com/crashvb/rea-docker" \
	org.opencontainers.image.version="${REA_VERSION}" \
	io.github.nationalsecurityagency.ghidra.version="${GHIDRA_VERSION}" \
	io.github.hopperapp.hopper.version="${HOPPER_VERSION}" \
	io.github.noelo-lab.kuna.version="${KUNA_VERSION}" \
	io.github.morluto.rea.revision="${REA_REVISION}"

# Install packages, download files ...
COPY --from=builder /tmp/hopper.deb /tmp/hopper.deb
RUN mkdir --parents /usr/share/man/man1/ && \
	docker-apt \
		/tmp/hopper.deb \
		libx11-6 \
		libxtst6 \
		openjdk-21-jdk-headless \
		procps \
		python3 \
		python3-dev \
		xauth \
		xvfb \
		&& \
	rm --force /tmp/hopper.deb && \
	rm --force --recursive /usr/share/man

# Configure: rea
ENV \
	GHIDRA_INSTALL_DIR=/opt/ghidra \
	HOPPER_LAUNCHER_PATH=/opt/hopper/bin/Hopper \
	MCP_HOST=0.0.0.0 \
	MCP_PORT=8765 \
	REA_GID=10000 \
	REA_HOME=/var/lib/rea \
	REA_KUNA_CACHE_DIR=/var/lib/rea/cache/kuna \
	REA_KUNA_COMMAND=/usr/local/bin/kuna \
	REA_NAME=rea \
	REA_UID=10000
COPY --from=builder /opt/ghidra/ /opt/ghidra/
COPY --from=builder /usr/local/bin/node /usr/local/bin/node
COPY --from=builder /usr/local/bin/kuna /usr/local/bin/kuna
COPY --from=builder /usr/local/lib/node_modules/ /usr/local/lib/node_modules/
RUN ln --symbolic ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
	ln --symbolic ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx && \
	ln --symbolic ../lib/node_modules/rea-agents/scripts/rea.mjs /usr/local/bin/rea && \
	groupadd --gid=${REA_GID} ${REA_NAME} && \
	useradd --create-home --gid=${REA_GID} --home-dir=${REA_HOME} --shell=/usr/sbin/nologin --uid=${REA_UID} ${REA_NAME} && \
	install --directory --group=${REA_NAME} --mode=0750 --owner=${REA_NAME} /etc/rea && \
	echo "${HOPPER_LAUNCHER_SHA256}  /opt/hopper/bin/Hopper" | sha256sum --check --strict && \
	java -version && \
	javac -version && \
	kuna --version && \
	rea mcp --http --help > /dev/null

# Configure: supervisor
COPY supervisord.rea.conf /etc/supervisor/conf.d/rea.conf

# Configure: entrypoint
COPY entrypoint.rea /etc/entrypoint.d/rea

# Configure: healthcheck
COPY healthcheck.rea /etc/healthcheck.d/rea

EXPOSE 8765/tcp

VOLUME ${REA_HOME}
