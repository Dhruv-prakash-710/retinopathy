import { createContext, useContext, useState } from 'react';

const AuthContext = createContext(null);

const MOCK_USERS = [
  { id: 1, username: 'admin', password: 'admin123', name: 'System Administrator', role: 'admin', facility: 'Central Command' },
  { id: 2, username: 'drSharma', password: 'doc123', name: 'Dr. Ananya Sharma', role: 'ophthalmologist', facility: 'District Hospital, Varanasi' },
  { id: 3, username: 'phc_rampur', password: 'phc123', name: 'Rajesh Kumar', role: 'phc_operator', facility: 'PHC Rampur, UP' },
  { id: 4, username: 'phc_bareilly', password: 'phc123', name: 'Priya Singh', role: 'phc_operator', facility: 'PHC Bareilly, UP' },
];

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    const saved = sessionStorage.getItem('rv_user');
    return saved ? JSON.parse(saved) : null;
  });

  const login = (username, password) => {
    const found = MOCK_USERS.find(u => u.username === username && u.password === password);
    if (found) {
      const userData = { ...found };
      delete userData.password;
      setUser(userData);
      sessionStorage.setItem('rv_user', JSON.stringify(userData));
      return { success: true, user: userData };
    }
    return { success: false, error: 'Invalid credentials' };
  };

  const logout = () => {
    setUser(null);
    sessionStorage.removeItem('rv_user');
  };

  return (
    <AuthContext.Provider value={{ user, login, logout, isAuthenticated: !!user }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');
  return context;
}

export default AuthContext;
