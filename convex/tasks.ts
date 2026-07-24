import { ConvexError, v } from 'convex/values'
import { mutation, query } from './_generated/server'

async function requireUserId(ctx: {
  auth: { getUserIdentity: () => Promise<{ subject: string } | null> }
}) {
  const identity = await ctx.auth.getUserIdentity()
  if (!identity) {
    throw new ConvexError('Authentication required')
  }
  return identity.subject
}

const taskPatch = {
  title: v.optional(v.string()),
  description: v.optional(v.union(v.string(), v.null())),
  tags: v.optional(v.array(v.string())),
  reminderAt: v.optional(v.union(v.number(), v.null())),
  sortOrder: v.optional(v.number()),
}

export const listTasks = query({
  args: {},
  handler: async (ctx) => {
    const userId = await requireUserId(ctx)
    const active = await ctx.db
      .query('tasks')
      .withIndex('by_user_completed_sort', (q) =>
        q.eq('userId', userId).eq('completed', false),
      )
      .collect()
    const completed = await ctx.db
      .query('tasks')
      .withIndex('by_user_completed_sort', (q) =>
        q.eq('userId', userId).eq('completed', true),
      )
      .collect()

    return [...active, ...completed].sort((a, b) => a.sortOrder - b.sortOrder)
  },
})

export const createTask = mutation({
  args: {
    title: v.string(),
    description: v.optional(v.string()),
    tags: v.optional(v.array(v.string())),
    reminderAt: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const title = args.title.trim()
    if (!title) {
      throw new ConvexError('Task title is required')
    }

    const userId = await requireUserId(ctx)
    const now = Date.now()
    const existing = await ctx.db
      .query('tasks')
      .withIndex('by_user', (q) => q.eq('userId', userId))
      .collect()

    return await ctx.db.insert('tasks', {
      userId,
      title,
      description: args.description?.trim() || undefined,
      tags: normalizeTags(args.tags ?? []),
      completed: false,
      reminderAt: args.reminderAt,
      createdAt: now,
      updatedAt: now,
      sortOrder:
        existing.length === 0
          ? now
          : Math.max(...existing.map((task) => task.sortOrder)) + 1,
    })
  },
})

export const updateTask = mutation({
  args: {
    id: v.id('tasks'),
    patch: v.object(taskPatch),
  },
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx)
    const task = await ctx.db.get(args.id)
    if (!task || task.userId !== userId) {
      throw new ConvexError('Task not found')
    }

    const patch: Record<string, string | number | Array<string> | undefined> =
      {}
    if (args.patch.title !== undefined) {
      const title = args.patch.title.trim()
      if (!title) {
        throw new ConvexError('Task title is required')
      }
      patch.title = title
    }
    if (args.patch.description !== undefined) {
      patch.description = args.patch.description?.trim() || undefined
    }
    if (args.patch.tags !== undefined) {
      patch.tags = normalizeTags(args.patch.tags)
      patch.dueDate = undefined
    }
    if (args.patch.reminderAt !== undefined) {
      patch.reminderAt = args.patch.reminderAt ?? undefined
      patch.reminderFiredAt = undefined
    }
    if (args.patch.sortOrder !== undefined) {
      patch.sortOrder = args.patch.sortOrder
    }

    await ctx.db.patch(args.id, { ...patch, updatedAt: Date.now() })
  },
})

function normalizeTags(tags: Array<string>) {
  const seen = new Set<string>()
  return tags.flatMap((tag) => {
    const normalized = tag.trim().replace(/^#+/, '')
    const key = normalized.toLocaleLowerCase()
    if (!normalized || seen.has(key)) return []
    seen.add(key)
    return [normalized]
  })
}

export const completeTask = mutation({
  args: { id: v.id('tasks') },
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx)
    const task = await ctx.db.get(args.id)
    if (!task || task.userId !== userId) {
      throw new ConvexError('Task not found')
    }
    await ctx.db.patch(args.id, { completed: true, updatedAt: Date.now() })
  },
})

export const uncompleteTask = mutation({
  args: { id: v.id('tasks') },
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx)
    const task = await ctx.db.get(args.id)
    if (!task || task.userId !== userId) {
      throw new ConvexError('Task not found')
    }
    await ctx.db.patch(args.id, { completed: false, updatedAt: Date.now() })
  },
})

export const deleteTask = mutation({
  args: { id: v.id('tasks') },
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx)
    const task = await ctx.db.get(args.id)
    if (!task || task.userId !== userId) {
      throw new ConvexError('Task not found')
    }
    await ctx.db.delete(args.id)
  },
})

export const markReminderFired = mutation({
  args: { id: v.id('tasks'), firedAt: v.number() },
  handler: async (ctx, args) => {
    const userId = await requireUserId(ctx)
    const task = await ctx.db.get(args.id)
    if (!task || task.userId !== userId) {
      throw new ConvexError('Task not found')
    }
    await ctx.db.patch(args.id, {
      reminderFiredAt: args.firedAt,
      updatedAt: Date.now(),
    })
  },
})
