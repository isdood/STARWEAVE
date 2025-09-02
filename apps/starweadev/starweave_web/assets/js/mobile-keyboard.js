// Mobile keyboard handling for better mobile experience
document.addEventListener('DOMContentLoaded', function() {
  const messageInput = document.getElementById('message-input');
  if (!messageInput) return;

  // Only apply on mobile devices
  const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  if (!isMobile) return;

  // Store the original window height
  let windowHeight = window.innerHeight;
  
  // Function to handle input focus
  function handleFocus() {
    // Add a small delay to ensure the keyboard is shown
    setTimeout(() => {
      // Scroll the input into view
      messageInput.scrollIntoView({ 
        behavior: 'smooth',
        block: 'center',
        inline: 'nearest'
      });
      
      // Add a class to the body when keyboard is visible
      document.body.classList.add('keyboard-visible');
    }, 100);
  }
  
  // Handle input blur
  function handleBlur() {
    document.body.classList.remove('keyboard-visible');
  }
  
  // Add event listeners
  messageInput.addEventListener('focus', handleFocus);
  messageInput.addEventListener('blur', handleBlur);
  
  // Handle window resize (for when keyboard appears/disappears)
  window.addEventListener('resize', function() {
    // If the height changed significantly, it's likely the keyboard
    const newHeight = window.innerHeight;
    if (Math.abs(windowHeight - newHeight) > 100) {
      if (document.activeElement === messageInput) {
        messageInput.scrollIntoView({ 
          behavior: 'smooth',
          block: 'center'
        });
      }
      windowHeight = newHeight;
    }
  });
});
