import { NextRequest, NextResponse } from 'next/server'

export async function DELETE(
  request: NextRequest,
  { params }: { params: { sessionId: string } }
) {
  try {
    const sessionId = params.sessionId
    const sessionServiceUrl = 'http://session-service:8001'
    
    console.log('Deleting session:', sessionId)
    console.log('Session service URL:', `${sessionServiceUrl}/sessions/${sessionId}`)
    console.log('Environment SESSION_SERVICE_URL:', process.env.SESSION_SERVICE_URL)
    
    const response = await fetch(`${sessionServiceUrl}/sessions/${sessionId}`, {
      method: 'DELETE'
    })
    
    if (!response.ok) {
      const errorText = await response.text()
      console.error('Session service error:', errorText)
      return NextResponse.json(
        { error: `Session service error: ${response.status}` },
        { status: response.status }
      )
    }
    
    const data = await response.json()
    console.log('Session deleted successfully:', data)
    
    return NextResponse.json(data)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: `Internal server error: ${error instanceof Error ? error.message : 'Unknown error'}` },
      { status: 500 }
    )
  }
}
