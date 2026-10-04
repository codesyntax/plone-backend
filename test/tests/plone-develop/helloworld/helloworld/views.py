from Products.Five.browser import BrowserView


class HelloWorldView(BrowserView):
    def __call__(self):
        return "Hello World ZCML!"
