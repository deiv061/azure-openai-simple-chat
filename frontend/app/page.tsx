'use client'

import { useState, useEffect, useRef } from 'react'
import { v4 as uuidv4 } from 'uuid'

interface Message {
  role: 'user' | 'assistant'
  content: string
  timestamp?: string
}

export default function ChatPage() {
  const [messages, setMessages] = useState<Message[]>([])
  const [inputMessage, setInputMessage] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [sessionId, setSessionId] = useState<string>('')
  const messagesEndRef = useRef<HTMLDivElement>(null)

  // Use internal API routes instead of external services
  const chatApiUrl = '/api/chat'
  const sessionApiUrl = '/api/sessions'

  // Debug environment variables
  console.log('Using internal API routes:')
  console.log('Chat API URL:', chatApiUrl)
  console.log('Session API URL:', sessionApiUrl)

  // Initialize session
  useEffect(() => {
    let storedSessionId = localStorage.getItem('chat-session-id')
    if (!storedSessionId) {
      storedSessionId = uuidv4()
      localStorage.setItem('chat-session-id', storedSessionId)
    }
    setSessionId(storedSessionId)
    
    // Load existing messages
    loadMessages(storedSessionId)
  }, [])

  // Auto-scroll to bottom
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const loadMessages = async (sessionId: string) => {
    try {
      const response = await fetch(`${sessionApiUrl}/${sessionId}/messages`)
      if (response.ok) {
        const data = await response.json()
        // Reverse messages to show in correct order (latest last)
        setMessages(data.messages.reverse())
      }
    } catch (error) {
      console.error('Error loading messages:', error)
    }
  }

  const sendMessage = async () => {
    if (!inputMessage.trim() || isLoading) return

    const userMessage: Message = {
      role: 'user',
      content: inputMessage.trim()
    }

    // Add user message to UI immediately
    setMessages(prev => [...prev, userMessage])
    setInputMessage('')
    setIsLoading(true)

    try {
      console.log('Sending message to:', chatApiUrl)
      console.log('Session ID:', sessionId)
      
      const response = await fetch(chatApiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          session_id: sessionId,
          message: userMessage.content
        })
      })

      console.log('Response status:', response.status)
      
      if (!response.ok) {
        const errorText = await response.text()
        console.error('Error response:', errorText)
        throw new Error(`Failed to send message: ${response.status} ${errorText}`)
      }

      const data = await response.json()
      console.log('Response data:', data)
      
      // Add assistant response to UI
      const assistantMessage: Message = {
        role: 'assistant',
        content: data.response
      }
      
      setMessages(prev => [...prev, assistantMessage])
    } catch (error) {
      console.error('Error sending message:', error)
      // Add error message
      const errorMessage: Message = {
        role: 'assistant',
        content: `Sorry, I encountered an error: ${error instanceof Error ? error.message : 'Unknown error'}. Please try again.`
      }
      setMessages(prev => [...prev, errorMessage])
    } finally {
      setIsLoading(false)
    }
  }

  const clearChat = async () => {
    try {
      console.log('Clearing chat for session:', sessionId)
      console.log('Session API URL:', `${sessionApiUrl}/${sessionId}`)
      
      const response = await fetch(`${sessionApiUrl}/${sessionId}`, {
        method: 'DELETE'
      })
      
      console.log('Clear chat response status:', response.status)
      
      if (!response.ok) {
        console.warn('Delete session failed, but continuing with local clear')
      }
      
      setMessages([])
      
      // Generate new session ID
      const newSessionId = uuidv4()
      localStorage.setItem('chat-session-id', newSessionId)
      setSessionId(newSessionId)
      console.log('New session ID:', newSessionId)
    } catch (error) {
      console.error('Error clearing chat:', error)
      // Still clear local messages even if backend call fails
      setMessages([])
      
      // Generate new session ID
      const newSessionId = uuidv4()
      localStorage.setItem('chat-session-id', newSessionId)
      setSessionId(newSessionId)
    }
  }

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      sendMessage()
    }
  }

  return (
    <div className="max-w-4xl mx-auto h-screen flex flex-col bg-white shadow-lg">
      {/* Header */}
      <div className="bg-primary-600 text-white p-4 flex justify-between items-center">
        <h1 className="text-xl font-semibold">OpenAI Chat App</h1>
        <div className="flex gap-2">
          <span className="text-sm opacity-75">Session: {sessionId.slice(0, 8)}...</span>
          <button
            onClick={clearChat}
            className="bg-primary-700 hover:bg-primary-800 px-3 py-1 rounded text-sm transition-colors"
          >
            Clear Chat
          </button>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.length === 0 ? (
          <div className="text-center text-gray-500 mt-8">
            <h2 className="text-lg font-medium mb-2">Welcome to OpenAI Chat App</h2>
            <p>Start a conversation with the AI assistant powered by OpenAI GPT-4o-mini.</p>
            <p className="text-sm mt-2">Your last 20 messages are saved and will be restored when you return.</p>
          </div>
        ) : (
          messages.map((message, index) => (
            <div
              key={index}
              className={`flex ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}
            >
              <div
                className={`max-w-xs lg:max-w-md px-4 py-2 rounded-lg ${
                  message.role === 'user'
                    ? 'bg-primary-600 text-white'
                    : 'bg-gray-200 text-gray-800'
                }`}
              >
                <p className="whitespace-pre-wrap">{message.content}</p>
              </div>
            </div>
          ))
        )}
        
        {isLoading && (
          <div className="flex justify-start">
            <div className="bg-gray-200 text-gray-800 max-w-xs lg:max-w-md px-4 py-2 rounded-lg">
              <div className="flex space-x-1">
                <div className="w-2 h-2 bg-gray-500 rounded-full animate-bounce"></div>
                <div className="w-2 h-2 bg-gray-500 rounded-full animate-bounce" style={{ animationDelay: '0.1s' }}></div>
                <div className="w-2 h-2 bg-gray-500 rounded-full animate-bounce" style={{ animationDelay: '0.2s' }}></div>
              </div>
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div className="border-t p-4">
        <div className="flex space-x-2">
          <textarea
            value={inputMessage}
            onChange={(e) => setInputMessage(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="Type your message here... (Press Enter to send)"
            className="flex-1 border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent resize-none"
            rows={1}
            disabled={isLoading}
          />
          <button
            onClick={sendMessage}
            disabled={!inputMessage.trim() || isLoading}
            className="bg-primary-600 hover:bg-primary-700 disabled:bg-gray-400 text-white px-6 py-2 rounded-lg transition-colors font-medium"
          >
            Send
          </button>
        </div>
      </div>
    </div>
  )
}
