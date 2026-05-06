module.exports = {
  apps: [
    {
      name: "ecommerce-api",
      script: "./dist/server/index.js",
      instances: 1,
      exec_mode: "fork",
      env: {
        NODE_ENV: "production",
        PORT: 3000,
      },
      max_restarts: 10,
      restart_delay: 1000,
    },
  ],
};
