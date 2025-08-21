import { NextRequest, NextResponse } from 'next/server'

export async function GET(
  request: NextRequest,
  { params }: { params: { sessionId: string } }
) {
  try {
    const sessionId = params.sessionId
    const sessionServiceUrl = 'http://session-service:8001'
    
    console.log('Getting messages for session:', sessionId)
    console.log('Session service URL:', `${sessionServiceUrl}/sessions/${sessionId}/messages`)
    console.log('Environment SESSION_SERVICE_URL:', process.env.SESSION_SERVICE_URL)
    
    const response = await fetch(`${sessionServiceUrl}/sessions/${sessionId}/messages`)
    
    if (!response.ok) {
      if (response.status === 404) {
        // Session not found, return empty messages
        return NextResponse.json({ messages: [], session_id: sessionId, total_messages: 0 })
      }
      
      const errorText = await response.text()
      console.error('Session service error:', errorText)
      return NextResponse.json(
        { error: `Session service error: ${response.status}` },
        { status: response.status }
      )
    }
    
    const data = await response.json()
    console.log('Session service response:', data)
    
    return NextResponse.json(data)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: `Internal server error: ${error instanceof Error ? error.message : 'Unknown error'}` },
      { status: 500 }
    )
  }
}
