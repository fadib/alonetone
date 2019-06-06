import Rails from 'rails-ujs'
import Sortable from 'sortablejs'
import { Controller } from 'stimulus'

export default class extends Controller {
  static targets = ['sortable', 'feedback']

  initialize() {
    if (this.data.get('enabled') === 'true') {
      this.setupSortable()
    }
  }

  //  "playlist"=>["10", "7", "146", "8", "88", "3895", "160", "8969", "9110", "10434", "14789", "15274", "18687"], "user_id"=>"sudara"}
  paramsFromSortables() {
    return `playlist[]=${this.sortable.toArray().join('&playlist[]=')}`
  }

  // only fire when order changed
  maybePostToSort() {
    const newParams = this.paramsFromSortables()
    if (newParams !== this.currentParams) {
      this.currentParams = newParams
      this.sort()
    }
  }

  setupSortable() {
    this.sortable = new Sortable(this.sortableTarget, {
      onEnd: () => this.maybePostToSort(),
    })
    this.currentParams = this.paramsFromSortables()
  }

  sort() {
    Rails.ajax({
      url: `${window.location}/sort.js`,
      type: 'POST',
      data: this.currentParams,
      success: this.displaySuccess.bind(this),
    })
  }

  displaySuccess() {
    const flashController = this.application.getControllerForElementAndIdentifier(document.getElementsByClassName('floating_feedback')[0], 'flash')
    flashController.alert('<div class="ajax_success"><span>Saved!</span></div>')
  }
}
