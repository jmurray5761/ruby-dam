import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["uploadButton"]

  connect() {
    this.setupCheckboxListeners()
    this.setupFormSubmit()
  }

  setupCheckboxListeners() {
    const checkboxes = document.querySelectorAll('input[type="checkbox"]')
    checkboxes.forEach(checkbox => {
      checkbox.addEventListener('change', () => this.updateUploadButton())
    })
  }

  setupFormSubmit() {
    const form = this.element
    form.addEventListener('submit', (e) => {
      e.preventDefault()
      this.handleSubmit(e)
    })
  }

  updateUploadButton() {
    const checkboxes = document.querySelectorAll('input[type="checkbox"]:checked')
    this.uploadButtonTarget.disabled = checkboxes.length === 0
  }

  selectAll() {
    const checkboxes = document.querySelectorAll('input[type="checkbox"]')
    checkboxes.forEach(checkbox => checkbox.checked = true)
    this.updateUploadButton()
  }

  deselectAll() {
    const checkboxes = document.querySelectorAll('input[type="checkbox"]')
    checkboxes.forEach(checkbox => checkbox.checked = false)
    this.updateUploadButton()
  }

  async handleSubmit(e) {
    const form = e.target
    const formData = new FormData(form)
    
    // Disable the upload button during submission
    this.uploadButtonTarget.disabled = true
    this.uploadButtonTarget.textContent = 'Uploading...'

    try {
      const response = await fetch(form.action, {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      const result = await response.json()

      if (response.ok) {
        // Show success message
        const message = result.message || 'Files uploaded successfully'
        this.showNotification(message, 'success')
        
        // Redirect to images index
        window.location.href = '/images'
      } else {
        // Show error message
        const errorMessage = result.errors?.join(', ') || 'Failed to upload files'
        this.showNotification(errorMessage, 'error')
      }
    } catch (error) {
      console.error('Upload error:', error)
      this.showNotification('An error occurred during upload', 'error')
    } finally {
      // Re-enable the upload button
      this.uploadButtonTarget.disabled = false
      this.uploadButtonTarget.textContent = 'Upload Selected'
    }
  }

  showNotification(message, type) {
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 p-4 rounded-lg shadow-lg ${
      type === 'success' ? 'bg-green-500' : 'bg-red-500'
    } text-white`
    notification.textContent = message
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.remove()
    }, 5000)
  }
} 