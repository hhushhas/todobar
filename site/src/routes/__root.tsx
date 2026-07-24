import { HeadContent, Scripts, createRootRoute } from '@tanstack/react-router'
import appCss from '../styles.css?url'
import type { ReactNode } from 'react'

const siteUrl = 'https://todobar.q9labs.ai'
const assetVersion = 'v4'
const socialImageUrl = `${siteUrl}/og-image.png?${assetVersion}`
const description =
  'TodoBar is a fast Mac menu bar queue for tasks and agent prompts. Add descriptions, tags, and dated reminders, then drag priorities into the order that matters.'

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { title: 'TodoBar - Prioritized tasks and prompts in your Mac menu bar' },
      { name: 'description', content: description },
      {
        name: 'keywords',
        content:
          'TodoBar, Mac todo app, menu bar todo list, agent prompt queue, task priorities, macOS reminders, lightweight task manager',
      },
      { name: 'application-name', content: 'TodoBar' },
      { name: 'apple-mobile-web-app-title', content: 'TodoBar' },
      { name: 'theme-color', content: '#16A799' },
      { name: 'color-scheme', content: 'light' },
      { name: 'robots', content: 'index, follow' },
      { property: 'og:type', content: 'website' },
      { property: 'og:url', content: siteUrl },
      { property: 'og:site_name', content: 'TodoBar' },
      { property: 'og:locale', content: 'en_US' },
      {
        property: 'og:title',
        content: 'TodoBar — Add it. Forget it. Check it off.',
      },
      { property: 'og:description', content: description },
      { property: 'og:image', content: socialImageUrl },
      { property: 'og:image:width', content: '1200' },
      { property: 'og:image:height', content: '630' },
      {
        property: 'og:image:alt',
        content:
          'TodoBar pinwheel logo next to the tagline "Add it. Forget it. Check it off."',
      },
      { name: 'twitter:card', content: 'summary_large_image' },
      {
        name: 'twitter:title',
        content: 'TodoBar — Add it. Forget it. Check it off.',
      },
      { name: 'twitter:description', content: description },
      { name: 'twitter:image', content: socialImageUrl },
      {
        name: 'twitter:image:alt',
        content:
          'TodoBar pinwheel logo next to the tagline "Add it. Forget it. Check it off."',
      },
    ],
    links: [
      { rel: 'stylesheet', href: appCss },
      { rel: 'canonical', href: siteUrl },
      {
        rel: 'icon',
        href: `/favicon.svg?${assetVersion}`,
        type: 'image/svg+xml',
      },
      { rel: 'icon', href: `/favicon.ico?${assetVersion}`, sizes: 'any' },
      {
        rel: 'apple-touch-icon',
        href: `/apple-touch-icon.png?${assetVersion}`,
      },
      { rel: 'manifest', href: '/site.webmanifest' },
    ],
  }),
  shellComponent: RootDocument,
})

function RootDocument({ children }: { children: ReactNode }) {
  const jsonLd = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'SoftwareApplication',
        name: 'TodoBar',
        operatingSystem: 'macOS 26.0 or later',
        applicationCategory: 'ProductivityApplication',
        description,
        url: siteUrl,
        image: socialImageUrl,
        softwareVersion: '0.1.0',
        downloadUrl: `${siteUrl}/releases/TodoBar-0.1.0.dmg`,
        offers: {
          '@type': 'Offer',
          price: '0',
          priceCurrency: 'USD',
        },
      },
      {
        '@type': 'FAQPage',
        mainEntity: [
          {
            '@type': 'Question',
            name: 'Is TodoBar free?',
            acceptedAnswer: {
              '@type': 'Answer',
              text: 'Yes — download it and start adding tasks. No account, no trial timer, no upsell screens.',
            },
          },
          {
            '@type': 'Question',
            name: 'Does TodoBar work offline?',
            acceptedAnswer: {
              '@type': 'Answer',
              text: 'Completely. Your tasks live on your Mac by default. Signing in is only needed if you want your list synced across Macs.',
            },
          },
          {
            '@type': 'Question',
            name: 'Which macOS versions does TodoBar support?',
            acceptedAnswer: {
              '@type': 'Answer',
              text: 'TodoBar requires macOS 26 or later and runs natively on Apple Silicon and Intel.',
            },
          },
          {
            '@type': 'Question',
            name: 'How do I open TodoBar?',
            acceptedAnswer: {
              '@type': 'Answer',
              text: 'Press Control-Option-T from anywhere, or click the pinwheel icon in your menu bar. The input field is already focused when it opens.',
            },
          },
          {
            '@type': 'Question',
            name: 'How do TodoBar priorities work?',
            acceptedAnswer: {
              '@type': 'Answer',
              text: 'Every active task has a visible rank, with P1 as the highest priority. Drag a priority badge onto another task to reorder the list, and TodoBar remembers the new order.',
            },
          },
          {
            '@type': 'Question',
            name: 'Is the TodoBar download safe to open?',
            acceptedAnswer: {
              '@type': 'Answer',
              text: 'Yes. The current universal Mac build is signed with a Developer ID, notarized by Apple, and works natively on Apple Silicon and Intel.',
            },
          },
        ],
      },
    ],
  }

  return (
    <html lang="en">
      <head>
        <HeadContent />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      </head>
      <body>
        {children}
        <Scripts />
      </body>
    </html>
  )
}
