export type AIRole = 'interviewer' | 'friend' | 'waiter' | 'debate_partner' | 'custom';

export interface RoleConfig {
  id: AIRole;
  name: string;
  nameZh: string;
  description: string;
  icon: string;
  systemPrompt: string;
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
  isVoice?: boolean;
}

export interface ChatConversation {
  roleId: AIRole;
  messages: ChatMessage[];
  lastActive: number;
}

export interface StreamChunk {
  type: 'text_delta' | 'error' | 'done';
  text?: string;
  message?: string;
}
