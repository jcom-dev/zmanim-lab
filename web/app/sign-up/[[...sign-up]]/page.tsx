import { SignUp } from '@clerk/nextjs';

export default function SignUpPage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-slate-900 to-slate-800">
      <SignUp
        appearance={{
          elements: {
            rootBox: 'mx-auto',
            card: 'bg-slate-800 shadow-2xl border border-slate-700',
            headerTitle: 'text-white',
            headerSubtitle: 'text-slate-300',
            socialButtonsBlockButton: 'bg-slate-700 border-slate-600 text-white hover:bg-slate-600',
            formFieldLabel: 'text-slate-300',
            formFieldInput: 'bg-slate-700 border-slate-600 text-white',
            formButtonPrimary: 'bg-blue-600 hover:bg-blue-500',
            footerActionLink: 'text-blue-400 hover:text-blue-300',
          },
        }}
      />
    </div>
  );
}
