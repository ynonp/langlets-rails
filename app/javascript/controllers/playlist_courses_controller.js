import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "coursesGrid", "loadingIndicator", "loadMoreButton", "infiniteScrollTrigger", "deleteOverlay"]
  static values = { 
    playlistId: Number,
    currentPage: Number,
    hasMore: Boolean
  }

  connect() {
    this.searchTimeout = null
    this.currentTag = "all"
    this.isLoading = false
    this.setupInfiniteScroll()
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  openDelete() {
    this.deleteOverlayTarget.classList.remove("hidden")
  }

  closeDelete() {
    this.deleteOverlayTarget.classList.add("hidden")
  }

  setupInfiniteScroll() {
    if (!this.hasInfiniteScrollTriggerTarget) return

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting && this.hasMoreValue && !this.isLoading) {
          this.loadMore()
        }
      })
    }, {
      rootMargin: '100px'
    })

    this.observer.observe(this.infiniteScrollTriggerTarget)
  }

  search() {
    // Clear previous timeout
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }

    // Set a new timeout to debounce the search
    this.searchTimeout = setTimeout(() => {
      this.performSearch()
    }, 300)
  }

  filterByTag(event) {
    const tag = event.currentTarget.dataset.tag
    this.currentTag = tag
    
    // Update active state on tag buttons
    this.updateActiveTag(event.currentTarget)
    
    // Reset page and perform search
    this.currentPageValue = 1
    this.performSearch()
  }

  updateActiveTag(activeButton) {
    // Remove active class from all tag buttons
    document.querySelectorAll('.tag-filter').forEach(button => {
      button.classList.remove('bg-emerald-500', 'text-white')
      button.classList.add('bg-gray-100', 'dark:bg-gray-800', 'text-gray-500', 'dark:text-gray-400', 'hover:bg-gray-200', 'dark:hover:bg-gray-700')
    })

    // Add active class to clicked button
    activeButton.classList.remove('bg-gray-100', 'dark:bg-gray-800', 'text-gray-500', 'dark:text-gray-400', 'hover:bg-gray-200', 'dark:hover:bg-gray-700')
    activeButton.classList.add('bg-emerald-500', 'text-white')
  }

  loadMore() {
    if (this.isLoading || !this.hasMoreValue) return
    
    this.currentPageValue += 1
    this.performSearch(true) // true = append mode
  }

  async performSearch(appendMode = false) {
    if (this.isLoading) return
    
    this.isLoading = true
    this.showLoading()

    try {
      const searchTerm = this.hasSearchInputTarget ? this.searchInputTarget.value : ''
      const params = new URLSearchParams({
        search: searchTerm,
        tag: this.currentTag,
        page: this.currentPageValue
      })

      const response = await fetch(`/playlists/${this.playlistIdValue}/search_courses?${params}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) {
        throw new Error('Network response was not ok')
      }

      const data = await response.json()
      
      if (appendMode) {
        // Append new courses to existing grid
        this.coursesGridTarget.insertAdjacentHTML('beforeend', data.courses)
      } else {
        // Replace all courses
        this.coursesGridTarget.innerHTML = data.courses
      }
      
      this.hasMoreValue = data.has_more
      this.updateLoadMoreButton()
      
    } catch (error) {
      console.error('Error fetching courses:', error)
      this.showError()
    } finally {
      this.isLoading = false
      this.hideLoading()
    }
  }

  showLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.remove('hidden')
    }
  }

  hideLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.add('hidden')
    }
  }

  updateLoadMoreButton() {
    if (this.hasLoadMoreButtonTarget) {
      if (this.hasMoreValue) {
        this.loadMoreButtonTarget.parentElement.classList.remove('hidden')
      } else {
        this.loadMoreButtonTarget.parentElement.classList.add('hidden')
      }
    }
  }

  showError() {
    // You could implement a more sophisticated error display here
    alert('Error loading courses. Please try again.')
  }
}
