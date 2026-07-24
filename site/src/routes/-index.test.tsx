import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { Route } from './index'
import type { ComponentType } from 'react'

describe('TodoBar landing page', () => {
  it('renders the branded hero and download call to action', () => {
    const Component = Route.options.component as ComponentType

    render(<Component />)

    expect(
      screen.getByRole('heading', {
        level: 1,
        name: /add it\.forget it\.check it off\./i,
      }),
    ).toBeTruthy()
    const download = screen.getByRole('link', { name: /download free/i })
    expect(download.getAttribute('href')).toBe('/releases/TodoBar-0.1.0.dmg')
    expect(
      screen.getByRole('link', { name: /zip also available/i }),
    ).toHaveProperty('href', 'http://localhost:3000/releases/TodoBar-0.1.0.zip')
    expect(screen.getByText(/signed & notarized/i)).toBeTruthy()
    expect(
      screen.getByRole('heading', { level: 3, name: /rank what matters/i }),
    ).toBeTruthy()
    expect(screen.getByLabelText(/priority 1; drag to reorder/i)).toBeTruthy()
    expect(
      screen.getByRole('link', { name: /download the latest dmg/i }),
    ).toHaveProperty('href', 'http://localhost:3000/releases/TodoBar-0.1.0.dmg')
  })
})
