import { createFileRoute } from '@tanstack/react-router'
import { useRef, useState } from 'react'
import type { CSSProperties } from 'react'

export const Route = createFileRoute('/')({ component: Home })

const PETALS = ['#16A799', '#F7B312', '#F4503C', '#2E7FE5']
const DOWNLOAD_URL = '/releases/TodoBar-0.1.0.dmg'
const ZIP_DOWNLOAD_URL = '/releases/TodoBar-0.1.0.zip'
const SUPPORT_EMAIL = 'mailto:shasanshoaib@gmail.com'

const FAQS = [
  {
    q: 'Is TodoBar free?',
    a: 'Yes — download it and start adding tasks. No account, no trial timer, no upsell screens.',
  },
  {
    q: 'Does it work offline?',
    a: 'Completely. Your tasks live on your Mac by default. Signing in is only needed if you want your list synced across Macs.',
  },
  {
    q: 'Which macOS versions are supported?',
    a: 'TodoBar requires macOS 26 or later and runs natively on Apple Silicon and Intel.',
  },
  {
    q: 'How do I open it?',
    a: 'Press ⌃⌥T from anywhere, or click the pinwheel in your menu bar. The input field is already focused when it opens.',
  },
  {
    q: 'How do priorities work?',
    a: 'Every active task has a visible rank — P1 is the task that matters most. Drag a priority badge onto another task to reorder the list, and TodoBar remembers the new order.',
  },
  {
    q: 'Is the download safe to open?',
    a: 'Yes. The current universal Mac build is signed with a Developer ID, notarized by Apple, and works natively on Apple Silicon and Intel.',
  },
]

const MOCK_TASKS = [
  {
    id: 'review',
    title: 'Review the agent’s final diff',
    description: 'Check the failing cases, then ship.',
    meta: <span className="mp-chip teal">#prompt</span>,
  },
  {
    id: 'handoff',
    title: 'Prepare the client handoff',
    description: 'Summarize decisions and open questions.',
    meta: <span className="mp-chip b">🔔 Today 3:00 PM</span>,
  },
  {
    id: 'notes',
    title: 'Draft launch notes',
    description: '',
    meta: <span className="mp-chip">#writing</span>,
  },
  {
    id: 'screenshots',
    title: 'Tidy the screenshots',
    description: '',
    meta: null,
  },
]

function PinwheelMark({ size = 24 }: { size?: number }) {
  const u = size / 24
  const petal = (cx: number, cy: number, color: string) => (
    <rect
      x={cx - 5.2 * u}
      y={cy - 5.2 * u}
      width={10.4 * u}
      height={10.4 * u}
      rx={2.6 * u}
      fill={color}
      transform={`rotate(45 ${cx} ${cy})`}
    />
  )

  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      {petal(7.4 * u, 7.4 * u, PETALS[0])}
      {petal(16.6 * u, 7.4 * u, PETALS[1])}
      {petal(7.4 * u, 16.6 * u, PETALS[2])}
      {petal(16.6 * u, 16.6 * u, PETALS[3])}
      <path
        d={`M ${14.2 * u} ${7.6 * u} l ${1.8 * u} ${
          1.8 * u
        } l ${3.2 * u} -${3.4 * u}`}
        stroke="#fff"
        strokeWidth={1.9 * u}
        fill="none"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}

function MockPopover() {
  const [tasks, setTasks] = useState(MOCK_TASKS)
  const [done, setDone] = useState<Set<string>>(() => new Set())
  const [dragging, setDragging] = useState<string | null>(null)
  const draggingTask = useRef<string | null>(null)
  const left = tasks.length - done.size

  function moveTask(sourceId: string, targetId: string) {
    if (sourceId === targetId) return

    setTasks((current) => {
      const sourceIndex = current.findIndex((task) => task.id === sourceId)
      const targetIndex = current.findIndex((task) => task.id === targetId)
      if (sourceIndex === -1 || targetIndex === -1) return current

      const next = [...current]
      const [source] = next.splice(sourceIndex, 1)
      next.splice(targetIndex, 0, source)
      return next
    })
  }

  return (
    <div className="mock-popover">
      <div className="mp-head">
        <span className="mark">
          <PinwheelMark size={19} />
        </span>
        <span className="mp-name">TodoBar</span>
        <span className="mp-dot" />
        <span className="mp-grow" />
        <span className="mp-avatar">4D</span>
      </div>
      <div className="mp-input">＋&nbsp; Add a task…</div>
      <div className="mp-rows">
        {tasks.map((task, index) => (
          <div
            className={`mp-row${done.has(task.id) ? ' done' : ''}${
              dragging === task.id ? ' dragging' : ''
            }`}
            style={{ '--pc': PETALS[index % 4] } as CSSProperties}
            key={task.id}
            data-task-id={task.id}
          >
            <button
              className="mp-check"
              type="button"
              aria-label={`Toggle ${task.title}`}
              onClick={() => {
                setDone((current) => {
                  const next = new Set(current)
                  if (next.has(task.id)) next.delete(task.id)
                  else next.add(task.id)
                  return next
                })
              }}
            >
              <span className="sh" />
              <svg viewBox="0 0 14 14">
                <path d="M2.5 7.5 L5.5 10.5 L11.5 3.5" />
              </svg>
            </button>
            <button
              type="button"
              className="mp-priority"
              aria-label={`Priority ${index + 1}; drag to reorder`}
              title="Drag to reorder"
              onPointerDown={(event) => {
                event.currentTarget.setPointerCapture(event.pointerId)
                draggingTask.current = task.id
                setDragging(task.id)
              }}
              onPointerMove={(event) => {
                const sourceId = draggingTask.current
                if (!sourceId) return

                const target = document
                  .elementFromPoint(event.clientX, event.clientY)
                  ?.closest<HTMLElement>('[data-task-id]')
                const targetId = target?.dataset.taskId
                if (targetId) moveTask(sourceId, targetId)
              }}
              onPointerUp={(event) => {
                event.currentTarget.releasePointerCapture(event.pointerId)
                draggingTask.current = null
                setDragging(null)
              }}
              onPointerCancel={() => {
                draggingTask.current = null
                setDragging(null)
              }}
              onKeyDown={(event) => {
                if (event.key === 'ArrowUp' && index > 0) {
                  event.preventDefault()
                  moveTask(task.id, tasks[index - 1].id)
                }
                if (event.key === 'ArrowDown' && index < tasks.length - 1) {
                  event.preventDefault()
                  moveTask(task.id, tasks[index + 1].id)
                }
              }}
            >
              P{index + 1}
            </button>
            <span className="mp-task">
              <span className="mp-title">{task.title}</span>
              {task.description ? (
                <span className="mp-description">{task.description}</span>
              ) : null}
            </span>
            {task.meta}
          </div>
        ))}
      </div>
      <div className="mp-foot">
        <span className="mp-drag-hint">↕ Drag P badges to reprioritize</span>
        <span className="mp-left">
          {left === 0
            ? 'All done 🎉'
            : `${left} task${left === 1 ? '' : 's'} left`}
        </span>
      </div>
    </div>
  )
}

function Marquee() {
  const items = ['CAPTURE IT', 'RANK IT', 'SHIP IT', 'REPEAT']
  const sequence = Array.from({ length: 8 }, (_, index) => ({
    item: items[index % 4],
    color: PETALS[index % 4],
    key: index,
  }))

  return (
    <div className="marquee">
      <div className="track">
        {[...sequence, ...sequence].map((entry, index) => (
          <span key={`${entry.key}-${index}`}>
            {entry.item}
            <span className="dot" style={{ background: entry.color }} />
          </span>
        ))}
      </div>
    </div>
  )
}

function Home() {
  return (
    <main className="design pinwheel-pop">
      <nav className="nav">
        <span className="brand">
          <span className="mark">
            <PinwheelMark size={24} />
          </span>
          TodoBar
        </span>
        <div className="links">
          <a href="#features">Features</a>
          <a href="#faq">FAQ</a>
          <a href={SUPPORT_EMAIL}>Support</a>
        </div>
        <a className="cta" href={DOWNLOAD_URL} download>
          Get TodoBar
        </a>
      </nav>
      <section className="hero">
        <div className="float-petal fp1" />
        <div className="float-petal fp2" />
        <div className="float-petal fp3" />
        <div className="float-petal fp4" />
        <p className="new-pill">
          <span>New</span> Priorities, prompt details, tags & reminders
        </p>
        <h1>
          Add it.
          <br />
          <span className="strike">Forget it.</span>
          <br />
          <span className="hl-teal">Check it off.</span>
        </h1>
        <p className="sub">
          Capture tasks and agent prompts from your menu bar. Add context, tags,
          and reminders—then drag priorities into the order that matters.
        </p>
        <div className="hero-ctas">
          <a className="btn-primary" href={DOWNLOAD_URL} download>
            Download free
          </a>
          <a className="btn-secondary" href="#features">
            See it in action
          </a>
        </div>
        <p className="cta-note">
          Free · signed & notarized · macOS 26+ · universal Mac build · 11 MB
          {' · '}
          <a href={ZIP_DOWNLOAD_URL} download>
            ZIP also available
          </a>
        </p>
        <div className="hero-mock">
          <MockPopover />
        </div>
      </section>
      <Marquee />
      <section className="latest" aria-labelledby="latest-heading">
        <div className="latest-copy">
          <p className="eyebrow">Latest notarized build</p>
          <h2 id="latest-heading">
            A tiny queue for <span className="hl-coral">serious context.</span>
          </h2>
          <p>
            TodoBar still opens in a keystroke. Now each task can carry the
            detail an agent prompt or real project needs—without turning your
            menu bar into a project-management system.
          </p>
          <a className="latest-download" href={DOWNLOAD_URL} download>
            Download the latest DMG <span>↓</span>
          </a>
          <p className="release-meta">
            Version 0.1.0 · Apple notarized · released July 23, 2026
          </p>
        </div>
        <ol className="workflow" aria-label="TodoBar workflow">
          <li>
            <span className="workflow-step">01</span>
            <strong>Capture</strong>
            <small>Title first. Return to add.</small>
          </li>
          <li>
            <span className="workflow-step">02</span>
            <strong>Add context</strong>
            <small>Description, tags, reminder.</small>
          </li>
          <li>
            <span className="workflow-step">03</span>
            <strong>Rank</strong>
            <small>Drag P1, P2, P3 into place.</small>
          </li>
          <li>
            <span className="workflow-step">04</span>
            <strong>Finish</strong>
            <small>Compact feedback. Clear head.</small>
          </li>
        </ol>
      </section>
      <section className="features-wrap" id="features">
        <h2 className="section-head">
          Structure when you need it.
          <br />
          <span className="hl-teal">Speed when you don&apos;t.</span>
        </h2>
        <div className="features">
          <div className="card">
            <div className="icon">
              <span>P1</span>
            </div>
            <h3>Rank what matters</h3>
            <p>
              Every active task gets a clear priority. Drag its P badge onto
              another task and the whole list settles into its new order.
            </p>
          </div>
          <div className="card">
            <div className="icon">
              <span>⌘</span>
            </div>
            <h3>Built for prompts</h3>
            <p>
              Keep multiline instructions beneath the task title, edit them
              inline, and copy the full description with one click.
            </p>
          </div>
          <div className="card">
            <div className="icon">
              <span>#</span>
            </div>
            <h3>Tags, not folders</h3>
            <p>
              Give related work a lightweight thread with reusable tags—no
              nested boards, admin rituals, or filing cabinet required.
            </p>
          </div>
          <div className="card">
            <div className="icon">
              <span>🔔</span>
            </div>
            <h3>Reminders with real dates</h3>
            <p>
              Choose a date and time, see clear Today and Tomorrow labels, and
              get a compact reminder card that names the task.
            </p>
          </div>
          <div className="card">
            <div className="icon">
              <span>⚡</span>
            </div>
            <h3>Still one keystroke</h3>
            <p>
              Press ⌃⌥T from anywhere. The capture field is already focused, and
              stays ready after Return so thoughts become tasks fast.
            </p>
          </div>
          <div className="card">
            <div className="icon">
              <span>☁️</span>
            </div>
            <h3>Private by default</h3>
            <p>
              Work offline with tasks stored on your Mac. Sign in only if you
              want the same list synced across every Mac you own.
            </p>
          </div>
        </div>
      </section>
      <section className="faq" id="faq">
        <h2 className="section-head">Quick answers</h2>
        <div className="faq-list">
          {FAQS.map((faq) => (
            <details className="faq-item" key={faq.q}>
              <summary>{faq.q}</summary>
              <p>{faq.a}</p>
            </details>
          ))}
        </div>
      </section>
      <section className="footband">
        <div className="bg-petal bp1" />
        <div className="bg-petal bp2" />
        <h2>Small app. Clear head.</h2>
        <p>
          Put the next task—and the context you need to finish it—one keystroke
          away.
        </p>
        <a className="btn-invert" href={DOWNLOAD_URL} download>
          Download for macOS
        </a>
      </section>
      <footer className="site-footer">
        <span className="brand">
          <span className="mark">
            <PinwheelMark size={18} />
          </span>
          TodoBar
        </span>
        <span className="foot-tag">Made for the Mac menu bar.</span>
        <nav className="foot-links" aria-label="Footer">
          <a href="#features">Features</a>
          <a href="#faq">FAQ</a>
          <a href={ZIP_DOWNLOAD_URL} download>
            ZIP
          </a>
          <a href={SUPPORT_EMAIL}>Support</a>
        </nav>
        <span className="copyright">© 2026 TodoBar</span>
      </footer>
    </main>
  )
}
