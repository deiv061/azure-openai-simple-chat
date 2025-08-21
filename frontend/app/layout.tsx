import './globals.css'

export const metadata = {
  title: 'OpenAI Chat App',
  description: 'Chat application with OpenAI GPT-4o-mini integration',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className="bg-gray-50 min-h-screen">
        {children}
      </body>
    </html>
  )
}
