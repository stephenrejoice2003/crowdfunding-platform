import React from "react";
import { Link } from "react-router-dom";

const HomePage = () => {
  return (
    <div className="bg-gradient-to-b from-blue-100 via-blue-200 to-blue-300 min-h-screen text-gray-800">
      {/* Navbar */}
      <nav className="bg-white shadow-lg">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center space-x-4">
              <Link to="/" className="text-2xl font-bold text-blue-500">
                Crowdfund<span className="text-orange-500">Now</span>
              </Link>
              <div className="hidden md:flex space-x-6">
                <Link to="/projects" className="hover:text-blue-500">
                  Projects
                </Link>
                <Link to="/about" className="hover:text-blue-500">
                  About
                </Link>
                <Link to="/contact" className="hover:text-blue-500">
                  Contact
                </Link>
              </div>
            </div>
            <div className="flex items-center space-x-4">
              <Link
                to="/login"
                className="py-2 px-4 bg-blue-500 text-white rounded-md hover:bg-blue-600 transition duration-300"
              >
                Login
              </Link>
              <Link
                to="/signup"
                className="py-2 px-4 border border-blue-500 text-blue-500 rounded-md hover:bg-blue-500 hover:text-white transition duration-300"
              >
                Sign Up
              </Link>
            </div>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <header className="relative">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20 text-center">
          <h1 className="text-5xl font-extrabold text-blue-600 drop-shadow-lg animate-fade-in-up">
            Empower Change, One Milestone at a Time
          </h1>
          <p className="mt-4 text-lg text-gray-700 animate-fade-in-up">
            Join our community of changemakers. Support innovative projects and
            track their success through transparent milestones.
          </p>
          <div className="mt-8 space-x-4">
            <Link
              to="/projects"
              className="py-3 px-6 bg-orange-500 text-white rounded-md text-lg hover:bg-orange-600 transition duration-300 animate-fade-in-up"
            >
              Explore Projects
            </Link>
            <Link
              to="/create"
              className="py-3 px-6 border border-orange-500 text-orange-500 rounded-md text-lg hover:bg-orange-500 hover:text-white transition duration-300 animate-fade-in-up"
            >
              Start a Project
            </Link>
          </div>
        </div>
        <div className="absolute bottom-0 left-1/2 transform -translate-x-1/2 w-64 h-64 bg-orange-200 rounded-full blur-3xl opacity-50"></div>
      </header>

      {/* Features Section */}
      <section className="bg-white py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-3xl font-bold text-blue-600">
            Why Choose CrowdfundNow?
          </h2>
          <div className="mt-8 grid gap-8 sm:grid-cols-2 lg:grid-cols-3">
            <div className="p-6 bg-blue-50 rounded-lg shadow-md animate-zoom-in">
              <h3 className="text-xl font-semibold text-blue-500">Transparency</h3>
              <p className="mt-2 text-gray-600">
                Monitor milestones and track project progress every step of the
                way.
              </p>
            </div>
            <div className="p-6 bg-blue-50 rounded-lg shadow-md animate-zoom-in">
              <h3 className="text-xl font-semibold text-blue-500">Community</h3>
              <p className="mt-2 text-gray-600">
                Be part of a global community supporting innovative ideas.
              </p>
            </div>
            <div className="p-6 bg-blue-50 rounded-lg shadow-md animate-zoom-in">
              <h3 className="text-xl font-semibold text-blue-500">Impact</h3>
              <p className="mt-2 text-gray-600">
                Directly contribute to projects that change lives and inspire
                others.
              </p>
            </div>
            {/* <div className="p-6 bg-blue-50 rounded-lg shadow-md animate-zoom-in">
              <h3 className="text-xl font-semibold text-blue-500">Trust</h3>
              <p className="mt-2 text-gray-600">
                Be rest assured that your donations are used wisely and for the right reasons.
              </p>
            </div> */}
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-blue-600 py-8">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-white text-center">
          <p>&copy; {new Date().getFullYear()} CrowdfundNow. All rights reserved.</p>
          <div className="mt-4 space-x-4">
            <Link to="/privacy" className="hover:underline">
              Privacy Policy
            </Link>
            <Link to="/terms" className="hover:underline">
              Terms of Service
            </Link>
          </div>
        </div>
      </footer>
    </div>
  );
};

export default HomePage;
