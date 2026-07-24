import { defineSchema, defineTable } from 'convex/server'
import { v } from 'convex/values'

export default defineSchema({
  tasks: defineTable({
    userId: v.string(),
    title: v.string(),
    description: v.optional(v.string()),
    tags: v.optional(v.array(v.string())),
    completed: v.boolean(),
    // Kept temporarily so existing synced tasks can migrate their old Due text into a tag.
    dueDate: v.optional(v.string()),
    reminderAt: v.optional(v.number()),
    reminderFiredAt: v.optional(v.number()),
    createdAt: v.number(),
    updatedAt: v.number(),
    sortOrder: v.number(),
  })
    .index('by_user', ['userId'])
    .index('by_user_completed_sort', ['userId', 'completed', 'sortOrder']),
})
