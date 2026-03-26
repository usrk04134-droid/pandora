FROM node:20-alpine

# Set the image version label
LABEL version="0.1.0"

# Add /usr/local/bin to the PATH environment variable
ENV PATH=/usr/local/bin:$PATH

# Install system dependencies and tools
RUN apk add --no-cache \
      bash=5.2.37-r0 \
      git=2.49.1-r0 \
    && npm install -g --loglevel=error \
      eslint@9.39.1 \
      eslint-plugin-jsx-a11y@6.10.2 \
      eslint-plugin-import@2.32.0 \
      eslint-plugin-security@3.0.1 \
      eslint-plugin-tailwindcss@3.18.2 \
      eslint-config-prettier@10.1.8 \
      eslint-plugin-prettier@5.5.4 \
      stylelint@16.25.0 \
      stylelint-config-standard@39.0.1 \
      stylelint-config-recommended-vue@1.6.1 \
      stylelint-config-prettier@9.0.5 \
      prettier@3.6.2 \
      vue-tsc@3.1.4 \
    && mkdir -p /etc/opt

# Copy ESLint configuration
COPY eslint.config.mjs /etc/opt/eslint.config.mjs
