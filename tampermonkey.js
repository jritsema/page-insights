// ==UserScript==
// @name         Page Insights
// @namespace    http://tampermonkey.net/
// @version      2024-02-12
// @description  Extract a summary and key insights from a web page.
// @author       John Ritsema
// @match        https://*/*
// @icon         data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==
// @grant        GM_addStyle
// ==/UserScript==

(function () {
  'use strict';
  console.log("web page insights loaded");

  const $ = document.querySelector.bind(document);
  setTimeout(() => {

    $('body').insertAdjacentHTML('afterbegin', getButtonHTML());

    let button = document.getElementById("tampermonkeybutton");
    button.addEventListener("click", ButtonClickAction, false);

    function ButtonClickAction(event) {
      button.innerHTML = 'Processing...';

      const model = "bedrock/anthropic.claude-3-sonnet-20240229-v1:0"
      const url = encodeURIComponent(window.location.href);
      const title = document.title;
      const baseUrl = "https://1234567890.execute-api.us-east-1.amazonaws.com/";
      const endpoint = `${baseUrl}/insights?title=${title}&url=${url}&model=${model}`;

      //todo: add error handling
      fetch(endpoint, {
        method: "POST",
        body: document.documentElement.innerText,
        headers: { "Content-Type": "text/html" }
      })
        .then(x => x.json())
        .then(data => {
          console.log(data);

          //poll server until status == "Complete"
          //then redirect to dashboard page
          const pageUrl = `${baseUrl}/pages/${data.id}`
          let interval = setInterval(() => {
            fetch(pageUrl)
              .then(x => x.json())
              .then(data => {
                console.log(data);
                if (data.status == "Complete") {
                  clearInterval(interval);
                  window.location.href = baseUrl;
                }
              });
          }, 30000)
        });
    }

  }, 1500);

  function getButtonHTML() {
    return `
      <div id="tampermonkeydiv">
        <button id="tampermonkeybutton" class="tampermonkeybutton" role="button">Page Insights</button>
      </div>
      <style>
        .tampermonkeybutton {
          z-index: 99999999;
          position: fixed;
          text-align: center;
          background-image: linear-gradient(144deg,#AF40FF, #5B42F3 50%,#00DDEB);
          border: 0;
          border-radius: 8px;
          color: #FFFFFF;
          font-family: Phantomsans, sans-serif;
          font-size: 12px;
          line-height: 1em;
          padding: 19px 24px;
          text-decoration: none;
          user-select: none;
          -webkit-user-select: none;
          cursor: pointer;
        }
      </style>`;
  }

})();
