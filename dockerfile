FROM nikolaik/python-nodejs:python3.8-nodejs14 AS base

WORKDIR /usr/app

# Stage 1: install dbt
FROM base AS dbt-builder
RUN python -m venv /usr/local/venv
RUN /usr/local/venv/bin/pip install dbt

# Install gcloud tool
RUN apt-get update && apt-get install -y --no-install-recommends curl
RUN curl https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-341.0.0-linux-x86_64.tar.gz > /tmp/gcloud-sdk.tar.gz
RUN mkdir /usr/local/gcloud && tar -C /usr/local/gcloud -xvf /tmp/gcloud-sdk.tar.gz

# Stage 2: build the common, backend, and frontend distributions
FROM base AS builder

# Install development dependencies for all
COPY package.json .
COPY yarn.lock .
COPY packages/common/package.json ./packages/common/
COPY packages/backend/package.json ./packages/backend/
COPY packages/frontend/package.json ./packages/frontend/

RUN yarn install --pure-lockfile --non-interactive

# Build common
COPY packages/common/tsconfig.json ./packages/common/
COPY packages/common/src/ ./packages/common/src/
RUN yarn --cwd ./packages/common/ build

# Build backend
COPY packages/backend/tsconfig.json ./packages/backend/
COPY packages/backend/src/ ./packages/backend/src
RUN yarn --cwd ./packages/backend/ build

# Build frontend
COPY packages/frontend ./packages/frontend
RUN yarn --cwd ./packages/frontend/ build

# Stage 3: execution environment for backend
FROM base as executor

# Copy in dbt
COPY --from=dbt-builder /usr/local/venv /usr/local/venv
ENV PATH $PATH:/usr/local/venv/bin

# Copy in gcloud
COPY --from=dbt-builder /usr/local/gcloud /usr/local/gcloud
ENV PATH $PATH:/usr/local/gcloud/google-cloud-sdk/bin

# Copy distributions into environment
COPY --from=builder /usr/app/packages/common/package.json /usr/app/packages/common/package.json
COPY --from=builder /usr/app/packages/common/dist /usr/app/packages/common/dist


COPY --from=builder /usr/app/packages/backend/package.json /usr/app/packages/backend/package.json
COPY --from=builder /usr/app/packages/backend/dist /usr/app/packages/backend/dist


COPY --from=builder /usr/app/packages/frontend/package.json /usr/app/packages/frontend/package.json
COPY --from=builder /usr/app/packages/frontend/build /usr/app/packages/frontend/build

# Install production dependencies
COPY package.json .
COPY yarn.lock .

ENV NODE_ENV production

RUN yarn install --pure-lockfile --non-interactive --production

# Run the backend
ENV DBT_PROJECT_DIR /usr/app/dbt
ENV DBT_PROFILES_DIR /usr/app/profiles
ENV LIGHTDASH_SPAWN_DBT true
WORKDIR /usr/app/packages/backend

# USER node
CMD ["yarn", "start"]
