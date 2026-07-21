# --- Build stage ---
FROM node:20-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Baked into the JS bundle at build time (Vite env vars are compile-time, not
# runtime). Left empty by default so the app calls relative URLs (/api/..., /ws)
# against whatever origin serves it — see nginx.conf, which proxies those paths
# to the backend container. Only override this if the frontend and backend are
# NOT served from the same origin.
ARG VITE_BACKEND_URL=""
ENV VITE_BACKEND_URL=${VITE_BACKEND_URL}
RUN npm run build

# --- Runtime stage ---
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
