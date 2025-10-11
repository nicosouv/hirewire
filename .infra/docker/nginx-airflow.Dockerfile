FROM nginx:1.27-alpine

# Install curl for healthchecks
RUN apk add --no-cache curl

# Copy Nginx configuration
COPY .infra/nginx/airflow-auth.conf /etc/nginx/conf.d/default.conf

# Remove default config
RUN rm -f /etc/nginx/conf.d/default.conf.bak

EXPOSE 8081

CMD ["nginx", "-g", "daemon off;"]
