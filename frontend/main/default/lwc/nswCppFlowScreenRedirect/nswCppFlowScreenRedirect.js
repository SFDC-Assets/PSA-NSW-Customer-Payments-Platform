import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";

export default 
class NswCppFlowScreenRedirect 
extends NavigationMixin(LightningElement) {
  _isConnected;
  _targetUrl;

  @api 
  get targetUrl() {
    return this._targetUrl;
  }

  set targetUrl(value) {
    this._targetUrl = value;

    if (this._isConnected) {
      this.redirect();
    }
  }

  _sameTab = true;

  @api 
  get sameTab() {
    return this._sameTab
  }

  set sameTab(value) {
    this._sameTab = value;
  }

  /* getters */

  get redirectingLabel() {
    return `Redirecting to ${this._targetUrl}`;
  }
  /* methods */

  redirect() {
    let targetUrl = this._targetUrl;

    if (!targetUrl.startsWith("http://") && !targetUrl.startsWith("https://")) {
      targetUrl = "https://" + targetUrl;
    }

    if (this._sameTab) {
      window.location.href = targetUrl;
    } else {
      this[NavigationMixin.Navigate]({
        type: 'standard__webPage',
        attributes: {
        url: targetUrl
        }
      },
        false
      );
    }
  }

  connectedCallback() {
    this._isConnected = true;

    if (this.targetUrl) {
      this.redirect();
    }
  }
}
