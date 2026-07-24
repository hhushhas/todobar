const domain = process.env.CLERK_FRONTEND_API_URL

export default {
  providers: domain
    ? [
        {
          domain,
          applicationID: 'convex',
        },
      ]
    : [],
}
