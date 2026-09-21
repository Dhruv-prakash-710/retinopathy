import './globals.css'
import Sidebar from '@/components/Sidebar'

export const metadata = {
  title: 'RetinaVision | DR Screening Pipeline',
  description: 'Automated Diabetic Retinopathy screening with clinically validated explainability.',
}

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <div className="app-layout">
          <Sidebar />
          <main className="main-content">
            <header className="top-header">
              <div className="header-title">
                {/* Could map pathname to title here if needed */}
              </div>
              <div className="user-profile">
                <div className="avatar">Dr</div>
                <div className="user-details">
                  <span className="user-name">Dr. A. Sharma</span>
                  <span className="user-role">Ophthalmologist</span>
                </div>
              </div>
            </header>
            <div className="content-scroll">
              {children}
            </div>
          </main>
        </div>
      </body>
    </html>
  )
}
