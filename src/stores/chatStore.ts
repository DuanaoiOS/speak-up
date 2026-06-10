import { create } from 'zustand';
import type { ChatMessage, ChatConversation, AIRole } from '@/types/chat';

interface ChatStore {
  conversations: Record<string, ChatConversation>;
  activeRole: AIRole | null;
  isStreaming: boolean;

  setActiveRole: (role: AIRole) => void;
  addMessage: (roleId: string, message: ChatMessage) => void;
  setStreaming: (streaming: boolean) => void;
  getConversation: (roleId: string) => ChatConversation | undefined;
  clearConversation: (roleId: string) => void;
  loadConversations: (conversations: Record<string, ChatConversation>) => void;
}

export const useChatStore = create<ChatStore>()((set, get) => ({
  conversations: {},
  activeRole: null,
  isStreaming: false,

  setActiveRole: (role) => set({ activeRole: role }),

  addMessage: (roleId, message) =>
    set((s) => {
      const conv = s.conversations[roleId] || {
        roleId: roleId as AIRole,
        messages: [],
        lastActive: Date.now(),
      };
      return {
        conversations: {
          ...s.conversations,
          [roleId]: {
            ...conv,
            messages: [...conv.messages, message],
            lastActive: Date.now(),
          },
        },
      };
    }),

  setStreaming: (streaming) => set({ isStreaming: streaming }),

  getConversation: (roleId) => get().conversations[roleId],

  clearConversation: (roleId) =>
    set((s) => {
      const { [roleId]: _, ...rest } = s.conversations;
      return { conversations: rest };
    }),

  loadConversations: (conversations) => set({ conversations }),
}));
