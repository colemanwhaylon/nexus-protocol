/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone', // Required for Docker deployment
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'ipfs.io',
        pathname: '/ipfs/**',
      },
      {
        protocol: 'https',
        hostname: '*.ipfs.dweb.link',
      },
      {
        protocol: 'http',
        hostname: 'localhost',
        port: '3000',
        pathname: '/metadata/**',
      },
    ],
  },
  webpack: (config) => {
    config.resolve.fallback = { fs: false, net: false, tls: false };
    config.externals.push('pino-pretty', 'lokijs', 'encoding');
    return config;
  },
};

module.exports = nextConfig;
