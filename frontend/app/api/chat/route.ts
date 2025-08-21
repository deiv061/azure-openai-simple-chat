import { NextRequest, NextResponse } from 'next/server'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    
    // Use Kubernetes service names directly
    const chatServiceUrl = 'http://chat-service:8000'
    
    console.log('Proxying request to:', `${chatServiceUrl}/chat`)
    console.log('Request body:', body)
    console.log('Environment CHAT_SERVICE_URL:', process.env.CHAT_SERVICE_URL)
    
    const response = await fetch(`${chatServiceUrl}/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body)
    })
    
    if (!response.ok) {
      const errorText = await response.text()
      console.error('Chat service error:', errorText)
      return NextResponse.json(
        { error: `Chat service error: ${response.status}` },
        { status: response.status }
      )
    }
    
    const data = await response.json()
    console.log('Chat service response:', data)
    
    return NextResponse.json(data)
  } catch (error) {
    console.error('API route error:', error)
    return NextResponse.json(
      { error: `Internal server error: ${error instanceof Error ? error.message : 'Unknown error'}` },
      { status: 500 }
    )
  }
}
