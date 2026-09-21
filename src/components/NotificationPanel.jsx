import { useState, useEffect, useRef } from 'react';
import './NotificationPanel.css';

const IconBell = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>
);

const MOCK_NOTIFICATIONS = [
  { id: 1, type: 'urgent', title: 'Level 4 PDR Detected', message: 'Patient P-1133 at PHC Bareilly — immediate referral required', time: '2 min ago', read: false },
  { id: 2, type: 'alert', title: 'Recapture Required', message: 'Scan DR-8289 rejected due to poor image quality. PHC notified.', time: '15 min ago', read: false },
  { id: 3, type: 'info', title: 'Batch Processing Complete', message: '12 fundus images from PHC Rampur analyzed. 2 referrals generated.', time: '1 hr ago', read: false },
  { id: 4, type: 'success', title: 'Review Validated', message: 'Dr. Sharma approved scan DR-8290 (Level 0, No DR)', time: '2 hrs ago', read: true },
  { id: 5, type: 'alert', title: 'GPU Utilization High', message: 'Processing queue at 92% capacity. Consider scheduling batch jobs.', time: '3 hrs ago', read: true },
  { id: 6, type: 'info', title: 'Model Update Available', message: 'DR classifier v3.2 trained with 12,000 additional images. Review changelog.', time: '1 day ago', read: true },
];

export default function NotificationPanel() {
  const [isOpen, setIsOpen] = useState(false);
  const [notifications, setNotifications] = useState(MOCK_NOTIFICATIONS);
  const panelRef = useRef(null);

  const unreadCount = notifications.filter(n => !n.read).length;

  useEffect(() => {
    const handleClickOutside = (e) => {
      if (panelRef.current && !panelRef.current.contains(e.target)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const markAllRead = () => {
    setNotifications(prev => prev.map(n => ({ ...n, read: true })));
  };

  const markRead = (id) => {
    setNotifications(prev => prev.map(n => n.id === id ? { ...n, read: true } : n));
  };

  const getTypeIcon = (type) => {
    switch (type) {
      case 'urgent': return '🔴';
      case 'alert': return '🟡';
      case 'success': return '✅';
      default: return 'ℹ️';
    }
  };

  const getTypeClass = (type) => {
    switch (type) {
      case 'urgent': return 'notif-urgent';
      case 'alert': return 'notif-alert';
      case 'success': return 'notif-success';
      default: return 'notif-info';
    }
  };

  return (
    <div className="notification-wrapper" ref={panelRef}>
      <button className="notification-bell" onClick={() => setIsOpen(!isOpen)} aria-label="Notifications">
        <IconBell />
        {unreadCount > 0 && <span className="notification-badge-count">{unreadCount}</span>}
      </button>

      {isOpen && (
        <div className="notification-dropdown">
          <div className="notif-header">
            <h4>Notifications</h4>
            {unreadCount > 0 && (
              <button className="notif-mark-all" onClick={markAllRead}>Mark all read</button>
            )}
          </div>
          <div className="notif-list">
            {notifications.map(notif => (
              <div
                key={notif.id}
                className={`notif-item ${getTypeClass(notif.type)} ${notif.read ? 'read' : 'unread'}`}
                onClick={() => markRead(notif.id)}
              >
                <span className="notif-type-icon">{getTypeIcon(notif.type)}</span>
                <div className="notif-content">
                  <div className="notif-title">{notif.title}</div>
                  <div className="notif-message">{notif.message}</div>
                  <div className="notif-time">{notif.time}</div>
                </div>
                {!notif.read && <span className="notif-unread-dot"></span>}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
